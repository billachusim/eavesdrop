import 'dart:io';

import 'package:eavesdrop/auth/auth_service.dart';
import 'package:eavesdrop/constants/avatars.dart';
import 'package:eavesdrop/constants/legal_links.dart';
import 'package:eavesdrop/widgets/primary_button.dart';
import 'package:eavesdrop/widgets/social_auth_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchPolicySite() async {
    final uri = Uri.parse(LegalLinks.privacyPolicy);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Text(
                "Eavesdrop",
                style: textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Conversations worth listening to.",
                style: textTheme.bodyMedium!.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF1C1C1C),
                  ),
                  tabs: const [
                    Tab(text: 'Create Account'),
                    Tab(text: 'Log In'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Continue as guest (limited listening)',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _SignUpTab(
                        textTheme: textTheme,
                        onPolicyTap: () => _launchPolicySite()),
                    _LoginTab(
                        textTheme: textTheme,
                        onPolicyTap: () => _launchPolicySite()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignUpTab extends StatefulWidget {
  const _SignUpTab(
      {required this.textTheme, required this.onPolicyTap});

  final TextTheme textTheme;
  final VoidCallback onPolicyTap;

  @override
  State<_SignUpTab> createState() => _SignUpTabState();
}

class _SignUpTabState extends State<_SignUpTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _termsAccepted = false;
  bool _isLoading = false;

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must accept the Terms & Policy to register.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = AuthService();
    final navigator = Navigator.of(context);

    // Select a random URL from the list
    final String randomAvatarUrl = Avatars.getRandomAvatar();

    try {
      final result = await auth.signUpWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
        _nicknameController.text,
        randomAvatarUrl,
      );

      if (result != null) {
        if (!mounted) return;
        navigator.pop(); // Pop the onboarding screen on success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final auth = AuthService();
    final navigator = Navigator.of(context);
    try {
      final result = await auth.signInWithGoogle();
      if (result != null) {
        if (!mounted) return;
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    final auth = AuthService();
    final navigator = Navigator.of(context);
    try {
      final result = await auth.signInWithApple();
      if (result != null) {
        if (!mounted) return;
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(labelText: 'Nickname'),
              validator: (val) => val!.isEmpty ? 'Enter a nickname' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (val) => val!.isEmpty ? 'Enter an email' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (val) =>
                  val!.length < 6 ? 'Enter a password 6+ characters long' : null,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: _termsAccepted,
                  onChanged: (bool? value) {
                    setState(() {
                      _termsAccepted = value ?? false;
                    });
                  },
                ),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: "I agree to the ",
                      style: widget.textTheme.bodySmall!
                          .copyWith(color: Colors.white70),
                      children: [
                        TextSpan(
                          text: "Terms & Policy",
                          style: widget.textTheme.bodySmall!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = widget.onPolicyTap,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Create Account',
              onPressed: _handleSignUp,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: widget.textTheme.bodySmall!
                        .copyWith(color: Colors.white38),
                  ),
                ),
                const Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 24),
            SocialAuthButton(
              type: SocialAuthType.google,
              onPressed: _handleGoogleSignIn,
              isLoading: _isLoading,
            ),
            if (Platform.isIOS) ...[
              const SizedBox(height: 12),
              SocialAuthButton(
                type: SocialAuthType.apple,
                onPressed: _handleAppleSignIn,
                isLoading: _isLoading,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LoginTab extends StatefulWidget {
  const _LoginTab({required this.textTheme, required this.onPolicyTap});

  final TextTheme textTheme;
  final VoidCallback onPolicyTap;

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = AuthService();
    final navigator = Navigator.of(context);

    try {
      final result = await auth.signInWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );
      if (result != null) {
        if (!mounted) return;
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final auth = AuthService();
    final navigator = Navigator.of(context);
    try {
      final result = await auth.signInWithGoogle();
      if (result != null) {
        if (!mounted) return;
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    final auth = AuthService();
    final navigator = Navigator.of(context);
    try {
      final result = await auth.signInWithApple();
      if (result != null) {
        if (!mounted) return;
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (val) => val!.isEmpty ? 'Enter an email' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (val) =>
                  val!.length < 6 ? 'Enter a password 6+ characters long' : null,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Log In',
              onPressed: _handleLogin,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: widget.textTheme.bodySmall!
                        .copyWith(color: Colors.white38),
                  ),
                ),
                const Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 24),
            SocialAuthButton(
              type: SocialAuthType.google,
              onPressed: _handleGoogleSignIn,
              isLoading: _isLoading,
            ),
            if (Platform.isIOS) ...[
              const SizedBox(height: 12),
              SocialAuthButton(
                type: SocialAuthType.apple,
                onPressed: _handleAppleSignIn,
                isLoading: _isLoading,
              ),
            ],
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                text: "By logging in, you agree to the ",
                style:
                    widget.textTheme.bodySmall!.copyWith(color: Colors.white70),
                children: [
                  TextSpan(
                    text: "Terms & Policy",
                    style: widget.textTheme.bodySmall!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = widget.onPolicyTap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
