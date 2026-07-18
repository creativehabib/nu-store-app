class AuthState {
  const AuthState({
    this.token,
    this.user,
    this.isLoading = false,
    this.isInitialized = false,
    this.requiresTwoFactor = false,
    this.isApproved = false,
    this.errorMessage,
  });

  final String? token;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final bool isInitialized;
  final bool requiresTwoFactor;
  final bool isApproved;
  final String? errorMessage;

  bool get isAuthenticated => token != null && isApproved && !requiresTwoFactor;

  AuthState copyWith({
    String? token,
    Map<String, dynamic>? user,
    bool? isLoading,
    bool? isInitialized,
    bool? requiresTwoFactor,
    bool? isApproved,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      requiresTwoFactor: requiresTwoFactor ?? this.requiresTwoFactor,
      isApproved: isApproved ?? this.isApproved,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
