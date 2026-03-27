import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/service_providers.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_intro_panel.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      next.whenOrNull(
        error: (error, _) => context.showAppSnackBar(error.toString()),
      );
    });

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthIntroPanel(
                      eyebrow: 'Criar conta',
                      title: 'Comece sua jornada com clareza.',
                      subtitle:
                          'Crie o acesso, confirme seu e-mail e depois entre no app para montar seu plano e registrar seus estudos.',
                    ),
                    const SizedBox(height: 20),
                    AppCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const AppLogo(size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Criar conta',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      Text(
                                        'Cadastro com confirmação opcional por e-mail.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nome',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? 'Informe seu nome'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? 'Informe o e-mail'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  (value == null || value.length < 6)
                                  ? 'Mínimo de 6 caracteres'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Confirmar senha',
                                prefixIcon: const Icon(
                                  Icons.verified_user_outlined,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'Confirme a senha';
                                }
                                if (value != _passwordController.text) {
                                  return 'As senhas não coincidem';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: authState.isLoading
                                    ? null
                                    : () async {
                                        if (!_formKey.currentState!
                                            .validate()) {
                                          return;
                                        }
                                        final result = await ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .signUp(
                                              email: _emailController.text
                                                  .trim(),
                                              password:
                                                  _passwordController.text,
                                              fullName: _nameController.text
                                                  .trim(),
                                            );
                                        if (!context.mounted ||
                                            result == null) {
                                          return;
                                        }
                                        if (result.requiresEmailConfirmation) {
                                          await showDialog<void>(
                                            context: context,
                                            builder: (dialogContext) => AlertDialog(
                                              title: const Text(
                                                'Confirme seu e-mail',
                                              ),
                                              content: Text(
                                                'Enviamos um e-mail para ${_emailController.text.trim()}. '
                                                'Confirme sua conta antes de fazer login.',
                                              ),
                                              actions: [
                                                FilledButton(
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop(),
                                                  child: const Text(
                                                    'Ok, vou confirmar',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (context.mounted) {
                                            context.go(AppRoutes.login);
                                          }
                                          return;
                                        }
                                        context.showAppSnackBar(
                                          'Conta criada com sucesso.',
                                        );
                                        if (!result.hasActiveSession) {
                                          context.go(AppRoutes.login);
                                          return;
                                        }

                                        final route = await ref
                                            .read(startupCoordinatorProvider)
                                            .resolvePostLoginRoute();
                                        if (!context.mounted) {
                                          return;
                                        }
                                        context.go(route);
                                      },
                                icon: const Icon(Icons.person_add_alt_1),
                                label: Text(
                                  authState.isLoading
                                      ? 'Criando conta...'
                                      : 'Criar conta',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => context.go(AppRoutes.login),
                              child: const Text('Já tenho conta'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
