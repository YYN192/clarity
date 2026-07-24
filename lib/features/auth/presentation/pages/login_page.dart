import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localizer.dart';
import '../../../weather/presentation/widgets/clay_container.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitEmail() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    final bloc = context.read<AuthBloc>();
    if (_isSignUp) {
      bloc.add(AuthSignUpWithEmailRequested(email, password));
    } else {
      bloc.add(AuthSignInWithEmailRequested(email, password));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final lang = settingsState.settings.language;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: BlocConsumer<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthError) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(state.message)));
              }
            },
            builder: (context, state) {
              final loading = state is AuthLoading;
              return SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            Localizer.localize(_isSignUp ? 'create_account' : 'welcome_back', lang),
                            style: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Localizer.localize('auth_subtitle', lang),
                            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 32),
                          _ClayField(
                            controller: _emailController,
                            hint: Localizer.localize('email', lang),
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _ClayField(
                            controller: _passwordController,
                            hint: Localizer.localize('password', lang),
                            icon: Icons.lock_outline,
                            obscure: _obscure,
                            onSubmitted: (_) => _submitEmail(),
                            suffix: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textSecondary, size: 20),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _ClayButton(
                            label: Localizer.localize(_isSignUp ? 'sign_up' : 'sign_in', lang),
                            filled: true,
                            loading: loading,
                            onTap: loading ? null : _submitEmail,
                          ),
                          const SizedBox(height: 20),
                          _OrDivider(label: Localizer.localize('or', lang)),
                          const SizedBox(height: 20),
                          _ClayButton(
                            label: Localizer.localize('continue_with_google', lang),
                            icon: Icons.g_mobiledata_rounded,
                            onTap: loading
                                ? null
                                : () => context.read<AuthBloc>().add(const AuthSignInWithGoogleRequested()),
                          ),
                          const SizedBox(height: 12),
                          _ClayButton(
                            label: Localizer.localize('continue_as_guest', lang),
                            icon: Icons.person_outline,
                            onTap: loading
                                ? null
                                : () => context.read<AuthBloc>().add(const AuthSignInAnonymouslyRequested()),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() => _isSignUp = !_isSignUp),
                              child: Text(
                                Localizer.localize(_isSignUp ? 'have_account_prompt' : 'no_account_prompt', lang),
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ClayField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _ClayField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          icon: Icon(icon, color: AppColors.atmosphericBlueGray, size: 20),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

class _ClayButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;

  const _ClayButton({
    required this.label,
    this.icon,
    this.filled = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClayContainer(
        borderRadius: 16,
        color: filled ? AppColors.cloudShadow : AppColors.getCardColor(),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: loading
            ? const Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: filled ? Colors.white : AppColors.textPrimary, size: 24),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: filled ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  final String label;
  const _OrDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.inactiveBlueGray)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        const Expanded(child: Divider(color: AppColors.inactiveBlueGray)),
      ],
    );
  }
}
