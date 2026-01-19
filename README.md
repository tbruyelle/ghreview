# ghreview

Review GitHub Pull Requests directly in Vim.

## Requirements

- Vim 8+ with `+channel` and `+job` features
- Go 1.21+
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

## Installation

1. Install the Go binary:

```bash
go install github.com/tbruyelle/ghreview/cmd/ghreview@latest
```

Or build from source:

```bash
git clone https://github.com/tbruyelle/ghreview.git
cd ghreview
make install
```

2. Add the plugin to Vim:

Using [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'tbruyelle/ghreview'
```

Or manually:
```vim
set runtimepath+=/path/to/ghreview
```

3. Make sure you're authenticated with GitHub CLI:

```bash
gh auth login
```

## Usage

Navigate to a git repository with a GitHub remote, then:

| Command | Description |
|---------|-------------|
| `:PRList` | List open PRs |
| `:PRList all` | List all PRs |
| `:PRDiff 123` | View diff for PR #123 |
| `:PRComments` | View comments on current PR |
| `:PRComment` | Add comment on current line |
| `:PRReview` | Submit a review |

## Key Bindings

**In PR list buffer:**
- `<CR>` - Open PR under cursor
- `q` - Close

**In diff buffer:**
- `o` - Open file at current line
- `]f` / `[f` - Next/previous file
- `:cnext` / `:cprev` - Navigate files via quickfix list
- `<leader>cc` - Add comment on current line
- `q` - Close

**In comments buffer:**
- `<CR>` - Jump to file/line
- `q` - Close

**In comment edit buffer:**
- `<leader>cs` - Submit comment
- `q` - Cancel

## Configuration

```vim
" Custom binary path (default: $GOPATH/bin/ghreview)
let g:ghreview_binary = '/path/to/ghreview'
```

## License

MIT
