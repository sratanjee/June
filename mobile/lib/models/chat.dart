enum ChatRole { user, june }

class ChatMessage {
  final ChatRole role;
  final String text;
  // True while June is still receiving deltas. The UI uses this to render a
  // pulsing dot at the end of the bubble.
  final bool streaming;
  // Optional muted error line shown below the bubble when a stream fails
  // mid-response. The partial text above is preserved.
  final String? errorText;

  ChatMessage({
    required this.role,
    required this.text,
    this.streaming = false,
    this.errorText,
  });

  ChatMessage copyWith({
    String? text,
    bool? streaming,
    String? errorText,
  }) {
    return ChatMessage(
      role: role,
      text: text ?? this.text,
      streaming: streaming ?? this.streaming,
      errorText: errorText ?? this.errorText,
    );
  }
}
