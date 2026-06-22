import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import '../theme.dart';

/// Sign-in / sign-up surface. Toggles between the two modes. On success this
/// just pops — `_Boot` reacts to the session change and routes onward.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { signIn, signUp }

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.signIn;

  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  void _switchMode(_Mode next) {
    if (_busy || next == _mode) return;
    setState(() {
      _mode = next;
      _error = null;
    });
  }

  String? _validate() {
    final email = _emailCtl.text.trim();
    final password = _passwordCtl.text;
    if (email.isEmpty || !email.contains('@')) {
      return 'That email doesn\'t look quite right.';
    }
    if (password.length < 6) {
      return 'Passwords need at least six characters.';
    }
    if (_mode == _Mode.signUp && password != _confirmCtl.text) {
      return 'Those passwords don\'t match.';
    }
    return null;
  }

  Future<void> _submit() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_mode == _Mode.signIn) {
        await AuthService.signInWithPassword(
          email: _emailCtl.text.trim(),
          password: _passwordCtl.text,
        );
        if (!mounted) return;
        Navigator.of(context).maybePop();
      } else {
        final res = await AuthService.signUp(
          email: _emailCtl.text.trim(),
          password: _passwordCtl.text,
        );
        if (!mounted) return;

        // Supabase doesn't throw on duplicate email (anti-enumeration). It
        // returns the user with an empty identities array and no session.
        // Detect that case and tell the user calmly to sign in instead.
        final user = res.user;
        final identities = user?.identities ?? const [];
        if (res.session == null && identities.isEmpty) {
          setState(() {
            _mode = _Mode.signIn;
            _confirmCtl.clear();
            _error =
                "You already have an account with that email. Sign in instead.";
          });
          return;
        }

        // Session created (email confirmation off) — proceed.
        if (res.session != null) {
          Navigator.of(context).maybePop();
          return;
        }

        // No session yet, but identities non-empty → email confirmation is
        // on. Stay on this screen and tell them what to expect.
        setState(() {
          _error =
              "Check your email for a confirmation link, then come back and sign in.";
        });
      }
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _error = _mode == _Mode.signIn
            ? "I couldn't sign you in. Check the email and password."
            : "I couldn't create that account. Try a different email.";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went sideways. Give it another try in a moment.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignIn = _mode == _Mode.signIn;
    final hero = isSignIn ? "Let's get you in." : 'Welcome.';
    final subhead = isSignIn
        ? 'A little housekeeping so June can find your numbers again.'
        : 'Set up an account so your numbers travel with you.';
    final cta = isSignIn ? 'Sign in' : 'Create account';
    final toggle = isSignIn
        ? 'New here? Create an account.'
        : 'Have an account? Sign in.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ModeToggle(
                    mode: _mode,
                    onChanged: _switchMode,
                  ),
                  const SizedBox(height: 36),
                  Text(
                    hero,
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subhead,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: JuneColors.neutralMuted,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 28),
                  _FieldLabel('Email'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailCtl,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'you@somewhere.com',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FieldLabel('Password'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordCtl,
                    enabled: !_busy,
                    obscureText: _obscurePassword,
                    autofillHints: isSignIn
                        ? const [AutofillHints.password]
                        : const [AutofillHints.newPassword],
                    textInputAction: isSignIn
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onSubmitted: (_) {
                      if (isSignIn) _submit();
                    },
                    decoration: InputDecoration(
                      hintText: 'At least six characters',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: JuneColors.neutralMuted,
                        ),
                        onPressed: _busy
                            ? null
                            : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                      ),
                    ),
                  ),
                  if (!isSignIn) ...[
                    const SizedBox(height: 18),
                    _FieldLabel('Confirm password'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmCtl,
                      enabled: !_busy,
                      obscureText: _obscureConfirm,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'Once more, to be sure',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: JuneColors.neutralMuted,
                          ),
                          onPressed: _busy
                              ? null
                              : () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: JuneColors.paper,
                            ),
                          )
                        : Text(cta),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => _switchMode(
                                isSignIn ? _Mode.signUp : _Mode.signIn,
                              ),
                      style: TextButton.styleFrom(
                        foregroundColor: JuneColors.neutralMuted,
                        textStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Text(toggle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: JuneColors.paperShade,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Sign in',
              selected: mode == _Mode.signIn,
              onTap: () => onChanged(_Mode.signIn),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Create account',
              selected: mode == _Mode.signUp,
              onTap: () => onChanged(_Mode.signUp),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? JuneColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? JuneColors.hairline : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? JuneColors.inkNavy : JuneColors.neutralMuted,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: JuneColors.neutralMuted,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: JuneColors.amberSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JuneColors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: JuneColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: JuneColors.inkNavy,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
