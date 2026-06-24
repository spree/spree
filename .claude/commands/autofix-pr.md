---
allowed-tools: allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checks:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*)
---

## Context

- PR metadata: !`gh pr view --json number,title,body,headRefName,baseRefName,author,labels`
- PR diff: !`gh pr diff`

## Your Task

Monitor a pull request and fix code review and CI issues automatically

1. Monitor the pull request for any code review comments from reviewers and agents like Bugbot or coderabbit
2. Monitor CI statuses, ignore codecov
3. Fix any code review comments and CI issues automatically
4. Commit and push the changes automatically
5. Retry in bounded cycles (e.g., max 10 iterations); if blocked (required review, failing checks, permission errors), stop and report blockers clearly
