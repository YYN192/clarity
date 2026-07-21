import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import 'login_page.dart';
import 'profile_page.dart';

/// Shows the profile when signed in, otherwise the login page. Because [AuthBloc]
/// is app-wide, signing in or out automatically flips this view — no manual
/// navigation needed.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      // Only switch on durable session states — ignore transient AuthLoading /
      // AuthError so an in-place action (editing the display name) never
      // momentarily flips this gate to the login page.
      buildWhen: (previous, current) =>
          current is Authenticated || current is Unauthenticated || current is AuthInitial,
      builder: (context, state) {
        if (state is Authenticated) {
          return ProfilePage(user: state.user);
        }
        if (state is Unauthenticated) {
          return const LoginPage();
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
