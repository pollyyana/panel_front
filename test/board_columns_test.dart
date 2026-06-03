import 'package:flutter_test/flutter_test.dart';
import 'package:panel/app/gitlab_status.dart';
import 'package:panel/app/models/project_models.dart';

void main() {
  ProjectPanel project(String name) => ProjectPanel(
    id: name,
    name: name,
    columns: [
      ColumnModel(
        id: '$name-pipeline',
        title: 'Pipeline',
        cards: [
          CardModel(
            id: '$name-pipeline-dev',
            issue: 'developer',
            status: GitLabCardStatus.pipeline(GitLabCiStatus.success),
          ),
        ],
      ),
      ColumnModel(
        id: '$name-job',
        title: 'Jobs',
        cards: [
          CardModel(
            id: '$name-job-build',
            issue: 'build-smoke',
            status: GitLabCardStatus.job(GitLabCiStatus.success),
          ),
        ],
      ),
      ColumnModel(
        id: '$name-merge_request',
        title: 'Merge requests',
        cards: [
          CardModel(
            id: '$name-mr-99',
            issue: '!#99',
            status: GitLabCardStatus.mergeRequest(GitLabMrState.opened),
          ),
        ],
      ),
      ColumnModel(
        id: '$name-issue',
        title: 'Issues',
        cards: [
          CardModel(
            id: '$name-issue-88',
            issue: '#88',
            status: GitLabCardStatus.issue(GitLabIssueState.opened),
          ),
        ],
      ),
    ],
  );

  test('buildCentralizedBoard agrupa as 4 colunas', () {
    final board = buildCentralizedBoard([project('panel'), project('log')]);

    expect(board.map((c) => c.id).toList(), [
      'pipeline',
      'job',
      'merge_request',
      'issue',
    ]);
    expect(board.map((c) => c.title).toList(), [
      'Pipeline',
      'Jobs',
      'Merge requests',
      'Issues',
    ]);
    expect(board.every((c) => c.cards.length == 2), isTrue);
  });

  test('buildCentralizedBoard filtra por projeto', () {
    final board = buildCentralizedBoard([
      project('panel'),
      project('log'),
    ], filterProject: 'panel');

    expect(board.every((c) => c.cards.length == 1), isTrue);
    expect(board.every((c) => c.cards.first.projectName == 'panel'), isTrue);
  });

  test('coluna Issues exibe cartões do mais recente ao mais antigo', () {
    final panel = ProjectPanel(
      id: 'panel',
      name: 'panel',
      columns: [
        ColumnModel(
          id: 'panel-issue',
          title: 'Issues',
          cards: [
            CardModel(
              id: 'new',
              issue: '#2 nova',
              status: GitLabCardStatus.issue(GitLabIssueState.opened),
            ),
            CardModel(
              id: 'old',
              issue: '#1 antiga',
              status: GitLabCardStatus.issue(GitLabIssueState.opened),
            ),
          ],
        ),
      ],
    );
    final issueCol = buildCentralizedBoard([
      panel,
    ]).firstWhere((c) => c.id == 'issue');
    expect(issueCol.cards.map((c) => c.issue).toList(), [
      '#2 nova',
      '#1 antiga',
    ]);
  });
}
