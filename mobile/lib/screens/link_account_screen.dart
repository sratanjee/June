import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../api/june_client.dart';
import '../theme.dart';

// NOTE: For Plaid Sandbox on iOS this screen needs no extra Info.plist entries.
// Production OAuth bank flows will require an Associated Domain entry + the
// Plaid universal-link host in Info.plist. Revisit when we move to Plaid
// Development / Production.
class LinkAccountScreen extends StatefulWidget {
  const LinkAccountScreen({super.key});

  @override
  State<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

enum _Status { idle, fetchingToken, linking, exchanging, syncing, done, error }

class _LinkAccountScreenState extends State<LinkAccountScreen> {
  final JuneClient _client = JuneClient();
  _Status _status = _Status.idle;
  String? _errorCopy;

  StreamSubscription<LinkSuccess>? _successSub;
  StreamSubscription<LinkExit>? _exitSub;

  @override
  void initState() {
    super.initState();
    _successSub = PlaidLink.onSuccess.listen(_onPlaidSuccess);
    _exitSub = PlaidLink.onExit.listen(_onPlaidExit);
  }

  @override
  void dispose() {
    _successSub?.cancel();
    _exitSub?.cancel();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() {
      _status = _Status.fetchingToken;
      _errorCopy = null;
    });

    try {
      final token = await _client.plaidLinkToken(userId: demoUserId);
      await PlaidLink.create(
        configuration: LinkTokenConfiguration(token: token.linkToken),
      );
      if (!mounted) return;
      setState(() => _status = _Status.linking);
      await PlaidLink.open();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _errorCopy = _humanError(err);
      });
    }
  }

  Future<void> _onPlaidSuccess(LinkSuccess success) async {
    if (!mounted) return;
    setState(() => _status = _Status.exchanging);
    try {
      await _client.plaidExchange(
        userId: demoUserId,
        publicToken: success.publicToken,
      );
      if (!mounted) return;
      setState(() => _status = _Status.syncing);
      await _client.plaidSync(userId: demoUserId);
      if (!mounted) return;
      setState(() => _status = _Status.done);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _errorCopy = _humanError(err);
      });
    }
  }

  void _onPlaidExit(LinkExit exit) {
    if (!mounted) return;
    // Only treat as "error" if Plaid actually surfaced one. A clean exit just
    // returns the screen to idle so the user can try again.
    if (exit.error != null) {
      setState(() {
        _status = _Status.error;
        _errorCopy =
            'Plaid closed before we finished. You can try again whenever you\'re ready.';
      });
    } else if (_status == _Status.linking) {
      setState(() => _status = _Status.idle);
    }
  }

  String _humanError(Object err) {
    final raw = err.toString();
    if (raw.contains('503')) {
      return "Bank linking isn't set up yet. Once your Plaid keys are in place, this will just work.";
    }
    return "Something got in the way. Try again in a moment.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(onClose: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 32),
              Text(
                'Link an account',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 14),
              Text(
                "We never see your bank login. Plaid handles the connection and gives June read-only access to balances and transactions.",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: JuneColors.neutralMuted,
                      height: 1.55,
                    ),
              ),
              const Spacer(),
              if (_status == _Status.done)
                _StatusCard(
                  tint: JuneColors.sageSurface,
                  title: 'Linked.',
                  detail: 'Your accounts are syncing. Head back to see them.',
                )
              else if (_status == _Status.error && _errorCopy != null)
                _StatusCard(
                  tint: JuneColors.amberSurface,
                  title: 'Hmm.',
                  detail: _errorCopy!,
                )
              else if (_isBusy)
                _StatusCard(
                  tint: JuneColors.paperShade,
                  title: _busyHeadline(),
                  detail: 'This usually takes a few seconds.',
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isBusy ? null : _continue,
                child: Text(_status == _Status.done
                    ? 'Done'
                    : 'Continue with Plaid'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: TextButton.styleFrom(
                  foregroundColor: JuneColors.neutralMuted,
                  textStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isBusy =>
      _status == _Status.fetchingToken ||
      _status == _Status.linking ||
      _status == _Status.exchanging ||
      _status == _Status.syncing;

  String _busyHeadline() {
    switch (_status) {
      case _Status.fetchingToken:
        return 'Getting ready…';
      case _Status.linking:
        return 'Talking to your bank.';
      case _Status.exchanging:
        return 'Securing the connection.';
      case _Status.syncing:
        return 'Pulling balances and transactions.';
      default:
        return '';
    }
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: JuneColors.inkNavy,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            'j',
            style: GoogleFonts.lora(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: JuneColors.paper,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'june',
          style: GoogleFonts.lora(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: JuneColors.inkNavy,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded,
              size: 22, color: JuneColors.neutralMuted),
          tooltip: 'Close',
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Color tint;
  final String title;
  final String detail;
  const _StatusCard({
    required this.tint,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(detail,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: JuneColors.neutralMuted,
                    height: 1.45,
                  )),
        ],
      ),
    );
  }
}
