import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SocialAuthType { google, apple }

class SocialAuthButton extends StatelessWidget {
  final SocialAuthType type;
  final VoidCallback onPressed;
  final bool isLoading;

  const SocialAuthButton({
    super.key,
    required this.type,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isGoogle = type == SocialAuthType.google;
    
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.transparent,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isGoogle ? Icons.g_mobiledata : Icons.apple,
                    color: Colors.white,
                    size: isGoogle ? 28 : 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isGoogle ? 'Continue with Google' : 'Continue with Apple',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
