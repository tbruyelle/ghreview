# ghreview - GitHub PR Review Plugin for Vim

## Project Overview

Vim 8+ plugin with a Go backend for reviewing GitHub Pull Requests directly in Vim. Communication happens via JSON-RPC over stdin/stdout.

## Architecture

```
┌─────────────────┐     JSON-RPC      ┌─────────────────┐
│   Vim 8+        │◄─────────────────►│   ghreview      │
│   (VimScript)   │   stdin/stdout    │   (Go binary)   │
└─────────────────┘                   └─────────────────┘
```

- Vim starts the Go binary as a job (`job_start`)
- Communication uses newline-delimited JSON (`nl` mode)
- Authentication via `gh auth token` (GitHub CLI)

## Project Structure

```
├── plugin/ghreview.vim      # Auto-loaded commands
├── autoload/ghreview.vim    # Lazy-loaded functions, job/channel management
├── cmd/ghreview/main.go     # Go entry point, JSON-RPC loop
├── rpc/server.go            # JSON-RPC dispatcher
├── github/client.go         # GitHub API client
├── pr/
│   ├── service.go           # Service wrapper
│   ├── list.go              # pr/list method
│   ├── diff.go              # pr/diff method
│   ├── comments.go          # pr/comments, pr/add_comment methods
│   └── review.go            # pr/submit_review method
├── Makefile
└── go.mod
```

## Build & Install

```bash
make install    # Installs binary to $GOPATH/bin/ghreview
```

Add to .vimrc:
```vim
Plug '~/src/hubreview'
" or
set runtimepath+=~/src/hubreview
```

## Vim Commands

| Command | Description |
|---------|-------------|
| `:PRList [state]` | List PRs (open/closed/all) |
| `:PRDiff {number}` | View PR diff |
| `:PRComments` | View comments on current PR |
| `:PRComment` | Add comment on current line |
| `:PRReview [event]` | Submit review (APPROVE/REQUEST_CHANGES/COMMENT) |

## Key Bindings (in PR buffers)

- `<CR>` - Open PR under cursor (in list) / Jump to comment location
- `]f` / `[f` - Next/previous file (in diff)
- `<leader>cc` - Add comment (in diff)
- `<leader>cs` - Submit comment (in comment edit)
- `q` - Close buffer

## JSON-RPC Methods

```json
{"method": "pr/list", "params": {"repo": "owner/repo", "state": "open"}}
{"method": "pr/diff", "params": {"repo": "owner/repo", "number": 123}}
{"method": "pr/comments", "params": {"repo": "owner/repo", "number": 123}}
{"method": "pr/add_comment", "params": {"repo": "owner/repo", "number": 123, "path": "file.go", "line": 42, "body": "..."}}
{"method": "pr/submit_review", "params": {"repo": "owner/repo", "number": 123, "event": "APPROVE", "body": "LGTM"}}
```

## Testing RPC Manually

```bash
echo '{"id":1,"method":"pr/list","params":{"repo":"owner/repo","state":"open"}}' | ghreview
```

## Configuration

```vim
let g:ghreview_binary = '/custom/path/to/ghreview'  " Default: $GOPATH/bin/ghreview
```

## Dependencies

- Go 1.21+
- Vim 8+ with `+channel` and `+job`
- GitHub CLI (`gh`) authenticated
