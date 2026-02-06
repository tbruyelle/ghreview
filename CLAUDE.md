# ghreview - GitHub PR Review Plugin for Vim

## IMPORTANT - Mandatory actions

**WHEN ASKING USER TO TEST**, run `make install` first if Go code was modified.

**BEFORE EACH COMMIT**, you must
- update documentation in `/doc` if necessary
- update README if necessary
- include modifications above in the commit

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

Install with vim-plug:
```vim
Plug 'github.com/tbruyelle/ghreview'
```

## Vim Commands

| Command | Description |
|---------|-------------|
| `:PRList [remote]` | List open PRs (remote defaults to "origin") |
| `:PRDiff {number}` | View PR diff |
| `:PRComments` | View comments on current PR |
| `:PRComment` | Add comment on current line |
| `:PRReview [event]` | Submit review (APPROVE/REQUEST_CHANGES/COMMENT) |
| `:PRSuggest` | Turn local edits into GitHub suggestion comments |

## Key Bindings (in PR buffers)

**PR list:**
- `<CR>` - Open PR under cursor

**Diff view:**
- `o` - Open file at current line
- `<C-n>` / `<C-m>` - Next/previous file
- `:cnext` / `:cprev` - Navigate files via quickfix list
- `<leader>cc` - Add comment (visual: GitHub suggestion)
- `q` - Close diff

**Comments view:**
- `<CR>` - Jump to comment location
- `q` - Close buffer

**Comment edit:**
- `<leader>cs` - Submit comment
- `q` - Cancel

**Suggest mode (`:PRSuggest`):**
- `<leader>cs` - Submit current suggestion
- `<leader>cn` - Skip current suggestion
- `q` - Abort remaining suggestions

## JSON-RPC Methods

```json
{"method": "pr/list", "params": {"repo": "owner/repo", "state": "open"}}
{"method": "pr/diff", "params": {"repo": "owner/repo", "number": 123}}
{"method": "pr/comments", "params": {"repo": "owner/repo", "number": 123}}
{"method": "pr/add_comment", "params": {"repo": "owner/repo", "number": 123, "path": "file.go", "line": 42, "start_line": 40, "body": "..."}}
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
