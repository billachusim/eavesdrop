import 'package:eavesdrop/auth/auth_service.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  String displayName = ''; // Add displayName state
  String error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(labelText: 'Display Name'), // Add displayName field
                validator: (val) => val!.isEmpty ? 'Enter a display name' : null,
                onChanged: (val) {
                  setState(() => displayName = val);
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (val) => val!.isEmpty ? 'Enter an email' : null,
                onChanged: (val) {
                  setState(() => email = val);
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (val) =>
                    val!.length < 6 ? 'Enter a password 6+ chars long' : null,
                onChanged: (val) {
                  setState(() => password = val);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text('Sign Up'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final navigator = Navigator.of(context);
                    // Pass displayName to the function
                    dynamic result = await _auth.signUpWithEmailAndPassword(
                        email, password, displayName);
                    if (result == null) {
                      setState(() => error = 'Please supply a valid email');
                    } else {
                      // No need to create user here, AuthService does it.
                      if (!mounted) return;
                      navigator.pop();
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
