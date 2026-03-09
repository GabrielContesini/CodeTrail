import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../domain/entities/app_entities.dart';
import '../../../shared/models/app_enums.dart';
import '../../../shared/models/app_view_models.dart';
import '../../../shared/models/page_tutorial.dart';
import '../../../shared/widgets/animated_reveal.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/sync_status_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../projects/application/projects_controller.dart';
import '../../reviews/application/reviews_controller.dart';
import '../../tasks/application/tasks_controller.dart';
import '../../tracks/application/tracks_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final goalAsync = ref.watch(currentGoalProvider);
    final tracksAsync = ref.watch(trackBlueprintsProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final reviewsAsync = ref.watch(reviewsProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final userId = ref.watch(currentUserIdProvider);

    return PageFrame(
      title: 'Dashboard',
      subtitle: 'Seu cockpit diário para estudar, revisar e entregar projetos.',
      tutorial: const PageTutorialData(
        id: 'dashboard',
        title: 'Como tirar proveito do dashboard',
        description:
            'Use esta tela como ponto de partida. Ela foi reorganizada para transformar intenção em ação.',
        steps: [
          'Comece por “Nova sessão” para registrar foco real.',
          'Use os cards rápidos para criar tarefa, revisão ou projeto.',
          'Acompanhe pendências do dia antes de trocar de página.',
        ],
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.newSession),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Nova sessão'),
        ),
      ],
      child: AsyncValueView(
        value: summaryAsync,
        data: (summary) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final wideHero = constraints.maxWidth >= 1240;
              final wideLists = constraints.maxWidth >= 1280;
              final actionColumns = constraints.maxWidth >= 1360
                  ? 3
                  : constraints.maxWidth >= 960
                  ? 2
                  : 1;
              final metricColumns = constraints.maxWidth >= 1400
                  ? 4
                  : constraints.maxWidth >= 1040
                  ? 3
                  : 2;

              return ListView(
                children: [
                  if (wideHero)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: AnimatedReveal(
                            child: _HeroStudyCard(summary: summary),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 4,
                          child: AnimatedReveal(
                            delay: const Duration(milliseconds: 70),
                            child: _TodayFocusCard(summary: summary),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        AnimatedReveal(
                          child: _HeroStudyCard(summary: summary),
                        ),
                        const SizedBox(height: 14),
                        AnimatedReveal(
                          delay: const Duration(milliseconds: 70),
                          child: _TodayFocusCard(summary: summary),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  AnimatedReveal(
                    delay: const Duration(milliseconds: 110),
                    child: SyncStatusCard(
                      userId: userId,
                      title: 'Sincronizacao',
                      subtitle:
                          'O app salva localmente primeiro e envia para o Supabase quando a conexao permite.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedReveal(
                    delay: const Duration(milliseconds: 140),
                    child: _WeeklyTargetCard(
                      summary: summary,
                      goalAsync: goalAsync,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DashboardSectionTitle(title: 'Ações rápidas'),
                  const SizedBox(height: 10),
                  _ResponsiveDashboardGrid(
                    columns: actionColumns,
                    spacing: 12,
                    children: [
                      _QuickActionCard(
                        title: 'Registrar estudo',
                        subtitle:
                            'Inicie um cronômetro e salve a sessão no histórico.',
                        icon: Icons.timer_outlined,
                        onTap: () => context.go(AppRoutes.newSession),
                      ),
                      _QuickActionCard(
                        title: 'Planejar trilha',
                        subtitle:
                            'Abra módulos e avance a trilha por carreira.',
                        icon: Icons.layers_outlined,
                        onTap: () => context.go(AppRoutes.tracks),
                      ),
                      _QuickActionCard(
                        title: 'Criar tarefa',
                        subtitle:
                            'Transforme próximo passo em execução concreta.',
                        icon: Icons.checklist_rounded,
                        onTap: () => context.go(AppRoutes.tasks),
                      ),
                      _QuickActionCard(
                        title: 'Gerar revisões',
                        subtitle: 'Programe D+1, D+7, D+15 e D+30 com alertas.',
                        icon: Icons.history_edu_outlined,
                        onTap: () => context.go(AppRoutes.reviews),
                      ),
                      _QuickActionCard(
                        title: 'Projeto prático',
                        subtitle: 'Acompanhe etapas e vincule o GitHub.',
                        icon: Icons.rocket_launch_outlined,
                        onTap: () => context.go(AppRoutes.projects),
                      ),
                      _QuickActionCard(
                        title: 'Abrir notas',
                        subtitle:
                            'Guarde resumos, comandos e insights por pasta.',
                        icon: Icons.note_alt_outlined,
                        onTap: () => context.go(AppRoutes.notes),
                      ),
                      _QuickActionCard(
                        title: 'Ver analytics',
                        subtitle:
                            'Consistência, tipos de estudo e volume semanal.',
                        icon: Icons.insights_outlined,
                        onTap: () => context.go(AppRoutes.analytics),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DashboardSectionTitle(title: 'Indicadores'),
                  const SizedBox(height: 10),
                  _ResponsiveDashboardGrid(
                    columns: metricColumns,
                    spacing: 12,
                    children: [
                      _MetricCard(
                        label: 'Horas na semana',
                        value: summary.hoursThisWeek.toStringAsFixed(1),
                        icon: Icons.schedule_rounded,
                      ),
                      _MetricCard(
                        label: 'Streak',
                        value: '${summary.streakDays} dias',
                        icon: Icons.local_fire_department_outlined,
                      ),
                      _MetricCard(
                        label: 'Revisões vencidas',
                        value: '${summary.overdueReviews}',
                        icon: Icons.notifications_active_outlined,
                      ),
                      _MetricCard(
                        label: 'Projetos ativos',
                        value: '${summary.activeProjects}',
                        icon: Icons.account_tree_outlined,
                      ),
                      _MetricCard(
                        label: 'Sessões registradas',
                        value: '${summary.totalSessions}',
                        icon: Icons.auto_graph_outlined,
                      ),
                      _MetricCard(
                        label: 'Progresso médio',
                        value: '${summary.trackProgress.toStringAsFixed(0)}%',
                        icon: Icons.trending_up_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DashboardSectionTitle(title: 'Painel operacional'),
                  const SizedBox(height: 10),
                  if (wideLists)
                    SizedBox(
                      height: 560,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: _AsyncListCard(
                                    title: 'Tarefas do dia',
                                    emptyLabel:
                                        'Sem tarefas pendentes. Crie a próxima ação para manter ritmo.',
                                    asyncValue: tasksAsync,
                                    builder: (tasks) => tasks
                                        .take(5)
                                        .map((task) => task.title)
                                        .toList(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _AsyncListCard(
                                    title: 'Revisões pendentes',
                                    emptyLabel:
                                        'Nenhuma revisão pendente agora. Gere um ciclo ao concluir um estudo importante.',
                                    asyncValue: reviewsAsync,
                                    builder: (reviews) => reviews
                                        .take(5)
                                        .map((review) => review.title)
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: _AsyncListCard(
                                    title: 'Trilhas em andamento',
                                    emptyLabel:
                                        'Selecione uma trilha para começar a medir progresso por skill.',
                                    asyncValue: tracksAsync,
                                    builder: (tracks) => tracks
                                        .take(5)
                                        .map(
                                          (track) =>
                                              '${track.track.name} • ${track.progressPercent.toStringAsFixed(0)}%',
                                        )
                                        .toList(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _AsyncListCard(
                                    title: 'Projetos ativos',
                                    emptyLabel:
                                        'Use projetos para transformar estudo em portfólio real.',
                                    asyncValue: projectsAsync,
                                    builder: (projects) => projects
                                        .take(5)
                                        .map(
                                          (project) =>
                                              '${project.project.title} • ${project.project.progressPercent.toStringAsFixed(0)}%',
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          height: 260,
                          child: _AsyncListCard(
                            title: 'Tarefas do dia',
                            emptyLabel:
                                'Sem tarefas pendentes. Crie a próxima ação para manter ritmo.',
                            asyncValue: tasksAsync,
                            builder: (tasks) =>
                                tasks.take(5).map((task) => task.title).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 260,
                          child: _AsyncListCard(
                            title: 'Revisões pendentes',
                            emptyLabel:
                                'Nenhuma revisão pendente agora. Gere um ciclo ao concluir um estudo importante.',
                            asyncValue: reviewsAsync,
                            builder: (reviews) => reviews
                                .take(5)
                                .map((review) => review.title)
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 260,
                          child: _AsyncListCard(
                            title: 'Trilhas em andamento',
                            emptyLabel:
                                'Selecione uma trilha para começar a medir progresso por skill.',
                            asyncValue: tracksAsync,
                            builder: (tracks) => tracks
                                .take(5)
                                .map(
                                  (track) =>
                                      '${track.track.name} • ${track.progressPercent.toStringAsFixed(0)}%',
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 260,
                          child: _AsyncListCard(
                            title: 'Projetos ativos',
                            emptyLabel:
                                'Use projetos para transformar estudo em portfólio real.',
                            asyncValue: projectsAsync,
                            builder: (projects) => projects
                                .take(5)
                                .map(
                                  (project) =>
                                      '${project.project.title} • ${project.project.progressPercent.toStringAsFixed(0)}%',
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HeroStudyCard extends StatelessWidget {
  const _HeroStudyCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final nextSessionLabel = summary.nextSession == null
        ? 'Nenhuma sessão iniciada ainda. Use um bloco de 25 a 50 minutos para começar.'
        : '${summary.nextSession!.type.label} • ${DateTimeUtils.shortDateTime(summary.nextSession!.startTime)} • ${DateTimeUtils.minutesToReadable(summary.nextSession!.durationMinutes)}';

    return AppCard(
      child: Container(
        constraints: const BoxConstraints(minHeight: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.82),
                ),
                child: Text(
                  summary.totalSessions == 0
                      ? 'Primeiro passo do dia'
                      : 'Seu próximo melhor movimento',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                summary.totalSessions == 0
                    ? 'Comece registrando sua primeira sessão.'
                    : 'Você já tem histórico. Agora use-o para acelerar.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Quando você registra sessão, o app consegue destravar trilha, revisar consistência e disparar lembretes úteis.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              Text(
                'Próxima sessão',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(nextSessionLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayFocusCard extends StatelessWidget {
  const _TodayFocusCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Pendências de tarefa',
        '${summary.pendingTasks}',
        Icons.check_circle_outline,
      ),
      (
        'Revisões urgentes',
        '${summary.overdueReviews}',
        Icons.history_toggle_off,
      ),
      (
        'Projetos ativos',
        '${summary.activeProjects}',
        Icons.rocket_launch_outlined,
      ),
    ];

    return AppCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O que exige atenção hoje',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.$3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.$2,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _WeeklyTargetCard extends StatelessWidget {
  const _WeeklyTargetCard({
    required this.summary,
    required this.goalAsync,
  });

  final DashboardSummary summary;
  final AsyncValue<UserGoalEntity?> goalAsync;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: goalAsync.when(
        data: (goal) {
          if (goal == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meta semanal',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Defina horas por dia e dias por semana para acompanhar meta, sobra de carga e ritmo real.',
                ),
              ],
            );
          }

          final targetHours = goal.hoursPerDay * goal.daysPerWeek;
          final completion = targetHours == 0
              ? 0.0
              : (summary.hoursThisWeek / targetHours).clamp(0.0, 1.25);
          final remainingHours = targetHours - summary.hoursThisWeek;
          final statusLabel = remainingHours <= 0
              ? 'Meta batida'
              : '${remainingHours.toStringAsFixed(1)}h para fechar a semana';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Meta semanal',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      '${goal.hoursPerDay}h x ${goal.daysPerWeek} dias',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${summary.hoursThisWeek.toStringAsFixed(1)}h de ${targetHours.toStringAsFixed(0)}h',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: completion > 1 ? 1 : completion,
                minHeight: 10,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 10),
              Text(statusLabel),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DashboardPill(
                    label: 'Foco',
                    value: goal.focusType.label,
                  ),
                  _DashboardPill(
                    label: 'Prazo',
                    value:
                        '${goal.deadline.day}/${goal.deadline.month}/${goal.deadline.year}',
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text(error.toString()),
      ),
    );
  }
}

class _DashboardPill extends StatelessWidget {
  const _DashboardPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.20),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResponsiveDashboardGrid extends StatelessWidget {
  const _ResponsiveDashboardGrid({
    required this.columns,
    required this.spacing,
    required this.children,
  });

  final int columns;
  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AsyncListCard<T> extends StatelessWidget {
  const _AsyncListCard({
    required this.title,
    required this.asyncValue,
    required this.builder,
    required this.emptyLabel,
  });

  final String title;
  final AsyncValue<T> asyncValue;
  final List<String> Function(T data) builder;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: asyncValue.when(
              data: (data) {
                final items = builder(data);
                if (items.isEmpty) {
                  return Text(emptyLabel);
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  itemBuilder: (context, index) => Text(
                    items[index],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(error.toString()),
            ),
          ),
        ],
      ),
    );
  }
}
