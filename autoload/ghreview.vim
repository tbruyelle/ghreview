" ghreview.vim - Autoload functions for GitHub PR Review
" These functions are lazy-loaded when first called

let s:job = v:null
let s:channel = v:null
let s:request_id = 0
let s:callbacks = {}
let s:current_pr = {}
let s:current_remote = 'origin'
let s:diff_files = []
let s:current_file_idx = 0
let s:pending_comment = {}
let s:showing_file = 0

" Initialize the channel to the ghreview binary
function! s:ensure_channel() abort
  if s:channel != v:null && ch_status(s:channel) == 'open'
    return 1
  endif

  let binary = g:ghreview_binary
  if !executable(binary)
    echoerr 'ghreview binary not found: ' . binary
    echoerr 'Run: make build'
    return 0
  endif

  try
    let s:job = job_start([binary], {
          \ 'in_mode': 'nl',
          \ 'out_mode': 'nl',
          \ 'out_cb': function('s:on_response'),
          \ 'err_cb': function('s:on_error'),
          \ })
    let s:channel = job_getchannel(s:job)
  catch
    echoerr 'Failed to start ghreview: ' . v:exception
    return 0
  endtry

  if job_status(s:job) != 'run'
    echoerr 'Failed to start ghreview process'
    return 0
  endif

  return 1
endfunction

" Send a JSON-RPC request
function! s:send_request(method, params, callback) abort
  if !s:ensure_channel()
    return
  endif

  let s:request_id += 1
  let request = {
        \ 'id': s:request_id,
        \ 'method': a:method,
        \ 'params': a:params,
        \ }

  let s:callbacks[s:request_id] = a:callback
  call ch_sendraw(s:channel, json_encode(request) . "\n")
endfunction

" Handle response from ghreview
function! s:on_response(channel, msg) abort
  if a:msg == ''
    return
  endif

  try
    let response = json_decode(a:msg)
  catch
    echoerr 'Failed to decode JSON: ' . a:msg
    return
  endtry

  if type(response) != v:t_dict
    return
  endif

  let id = get(response, 'id', 0)
  if !has_key(s:callbacks, id)
    return
  endif

  let Callback = s:callbacks[id]
  unlet s:callbacks[id]

  if has_key(response, 'error') && response.error != v:null
    echoerr 'ghreview error: ' . response.error.message
    return
  endif

  call Callback(get(response, 'result', v:null))
endfunction

" Handle errors from ghreview
function! s:on_error(channel, msg) abort
  echoerr 'ghreview error: ' . a:msg
endfunction

" Wrap text at specified width, returns list of lines
function! s:wrap_text(text, width) abort
  let lines = []
  let words = split(a:text, '\s\+')
  let current = ''
  for word in words
    if current == ''
      let current = word
    elseif len(current) + 1 + len(word) <= a:width
      let current .= ' ' . word
    else
      call add(lines, current)
      let current = word
    endif
  endfor
  if current != ''
    call add(lines, current)
  endif
  return lines
endfunction

" Get the current repository (owner/repo) from s:current_remote
function! s:get_repo() abort
  let remote_url = system('git remote get-url ' . shellescape(s:current_remote) . ' 2>/dev/null')
  if v:shell_error != 0
    echoerr 'Not in a git repository or no ' . s:current_remote . ' remote'
    return ''
  endif
  let matches = matchlist(trim(remote_url), 'github\.com[:/]\([^/]\+\)/\([^/.]\+\)')
  if len(matches) < 3
    echoerr 'Could not parse GitHub repository from remote: ' . trim(remote_url)
    return ''
  endif
  return matches[1] . '/' . matches[2]
endfunction

" List PRs
" Optional argument: remote name (default: 'origin')
function! ghreview#list(...) abort
  let s:current_remote = a:0 > 0 && a:1 != '' ? a:1 : 'origin'

  let repo = s:get_repo()
  if repo == ''
    return
  endif

  echo 'Fetching PRs...'
  call s:send_request('pr/list', {'repo': repo, 'state': 'open'}, function('s:on_pr_list'))
endfunction

function! s:on_pr_list(result) abort
  if a:result == v:null
    echo 'No PRs found'
    return
  endif

  " Create or switch to PR list buffer
  let bufname = 'ghreview://pr-list'
  let bufnr = bufnr(bufname)
  if bufnr == -1
    execute 'new ' . bufname
  else
    execute 'buffer ' . bufnr
  endif

  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal nowrap
  setlocal filetype=ghreview-list

  " Clear and populate buffer
  setlocal modifiable
  silent! %delete _

  call append(0, '# Pull Requests - ' . s:get_repo())
  call append(1, '')
  call append(2, printf('%-6s %-60s %-20s %-10s', '#', 'Title', 'Author', 'Updated'))
  call append(3, repeat('-', 100))

  let line = 4
  for pr in a:result
    let draft = pr.draft ? '[DRAFT] ' : ''
    let title = draft . pr.title
    if len(title) > 58
      let title = title[:55] . '...'
    endif
    call append(line, printf('%-6d %-60s %-20s %-10s', pr.number, title, pr.author, pr.updated_at))
    let line += 1
  endfor

  setlocal nomodifiable
  call cursor(5, 1)
  redraw
  echo 'Found ' . len(a:result) . ' PR(s)'
endfunction

" Open PR under cursor
function! ghreview#open_pr_under_cursor() abort
  let line = getline('.')
  let matches = matchlist(line, '^\s*\(\d\+\)\s')
  if len(matches) < 2
    return
  endif
  let pr_number = str2nr(matches[1])
  call ghreview#diff(pr_number)
endfunction

" Get PR number for current branch
function! s:get_pr_for_branch() abort
  let branch = trim(system('git branch --show-current 2>/dev/null'))
  if v:shell_error != 0 || branch == ''
    echoerr 'Not on a git branch'
    return 0
  endif

  " Use gh CLI to find PR for this branch
  let pr_json = system('gh pr view --json number 2>/dev/null')
  if v:shell_error != 0
    echoerr 'No PR found for branch: ' . branch
    return 0
  endif

  try
    let pr = json_decode(pr_json)
    return pr.number
  catch
    echoerr 'Failed to parse PR info'
    return 0
  endtry
endfunction

" Show diff for a PR
function! ghreview#diff(...) abort
  let repo = s:get_repo()
  if repo == ''
    return
  endif

  " Get PR number from argument or detect from current branch
  if a:0 > 0 && a:1 != ''
    let number = a:1
  else
    echo 'Detecting PR for current branch...'
    let number = s:get_pr_for_branch()
    if number == 0
      return
    endif
  endif

  let s:current_pr.number = number
  echo 'Fetching diff for PR #' . number . '...'
  call s:send_request('pr/diff', {'repo': repo, 'number': number}, function('s:on_pr_diff'))
endfunction

function! s:on_pr_diff(result) abort
  if a:result == v:null
    echo 'Failed to get diff'
    return
  endif

  let s:current_pr = a:result
  let s:diff_files = a:result.files
  let s:current_file_idx = 0

  if len(s:diff_files) == 0
    echo 'No files changed in this PR'
    return
  endif

  " Checkout the PR branch
  call s:checkout_pr_branch(a:result.head_branch)

  " First show the diff
  call s:show_current_file()

  " Then populate and open quickfix list
  call s:populate_qflist()

  " Force redraw since we're in an async callback
  redraw
endfunction

function! s:checkout_pr_branch(branch) abort
  if a:branch == ''
    return
  endif

  let current_branch = trim(system('git branch --show-current 2>/dev/null'))
  if current_branch == a:branch
    return
  endif

  echo 'Checking out branch: ' . a:branch . '...'
  let output = system('git checkout ' . shellescape(a:branch) . ' 2>&1')
  if v:shell_error != 0
    " Try to fetch and checkout if branch doesn't exist locally
    let output = system('git fetch origin ' . shellescape(a:branch) . ' && git checkout ' . shellescape(a:branch) . ' 2>&1')
    if v:shell_error != 0
      echohl WarningMsg
      echo 'Could not checkout branch ' . a:branch . ': ' . trim(output)
      echohl None
      return
    endif
  endif
  echo 'Switched to branch: ' . a:branch
endfunction

function! s:populate_qflist() abort
  let qf_items = []
  let idx = 0
  for file in s:diff_files
    let status_text = file.filename . ' | ' . file.status . ' (+' . file.additions . ' -' . file.deletions . ')'
    call add(qf_items, {
          \ 'filename': 'ghreview://diff/' . file.filename,
          \ 'lnum': 1,
          \ 'text': status_text,
          \ 'nr': idx + 1,
          \ })
    let idx += 1
  endfor

  call setqflist([], 'r', {
        \ 'title': 'PR #' . s:current_pr.number . ': ' . s:current_pr.title,
        \ 'items': qf_items,
        \ })

  " Remember current window (the diff window)
  let diff_win = winnr()
  " Open qflist window
  copen
  " Return focus to diff window
  execute diff_win . 'wincmd w'
endfunction

function! s:show_current_file() abort
  if s:current_file_idx >= len(s:diff_files)
    let s:current_file_idx = len(s:diff_files) - 1
  endif
  if s:current_file_idx < 0
    let s:current_file_idx = 0
  endif

  let file = s:diff_files[s:current_file_idx]

  " Prevent BufReadCmd from re-entering
  let s:showing_file = 1

  " Create diff buffer (use edit to take full screen, not split)
  let bufname = 'ghreview://diff/' . file.filename
  let bufnr = bufnr(bufname)
  if bufnr == -1
    execute 'edit ' . fnameescape(bufname)
  else
    execute 'buffer ' . bufnr
  endif

  let s:showing_file = 0

  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal filetype=ghreview-diff

  setlocal modifiable
  silent! %delete _

  " Header
  let line = 0
  call append(line, '# PR #' . s:current_pr.number . ': ' . s:current_pr.title)
  let line += 1

  " PR description/body
  if has_key(s:current_pr, 'description') && s:current_pr.description != ''
    call append(line, '#')
    let line += 1
    for desc_line in split(s:current_pr.description, '\n')
      if desc_line == ''
        call append(line, '#')
        let line += 1
      else
        for wrapped in s:wrap_text(desc_line, 78)
          call append(line, '# ' . wrapped)
          let line += 1
        endfor
      endif
    endfor
  endif

  call append(line, '#')
  let line += 1
  call append(line, '# File ' . (s:current_file_idx + 1) . '/' . len(s:diff_files) . ': ' . file.filename)
  let line += 1
  call append(line, '# Status: ' . file.status . ' (+' . file.additions . ' -' . file.deletions . ')')
  let line += 1
  call append(line, '# Navigation: o open file, ]f/[f next/prev file, <leader>cc comment, <leader>cr review, q close')
  let line += 1
  call append(line, '')
  let line += 1

  " Patch content
  let patch_start = line + 1
  if file.patch != ''
    let patch_lines = split(file.patch, '\n')
    for pline in patch_lines
      call append(line, pline)
      let line += 1
    endfor
  else
    call append(line, '(binary file or no diff available)')
    let line += 1
  endif

  setlocal nomodifiable

  " Set up syntax highlighting for diff
  syntax match DiffAdd /^+.*/
  syntax match DiffDelete /^-.*/
  syntax match DiffChange /^@@.*/
  highlight link DiffAdd DiffAdd
  highlight link DiffDelete DiffDelete
  highlight link DiffChange DiffChange

  call cursor(patch_start, 1)
  redraw
  echo 'File ' . (s:current_file_idx + 1) . '/' . len(s:diff_files) . ': ' . file.filename
endfunction

function! ghreview#next_file() abort
  let s:current_file_idx += 1
  call s:show_current_file()
  " Sync qflist position without jumping (to avoid triggering BufReadCmd)
  call setqflist([], 'a', {'idx': s:current_file_idx + 1})
endfunction

function! ghreview#prev_file() abort
  let s:current_file_idx -= 1
  call s:show_current_file()
  " Sync qflist position without jumping (to avoid triggering BufReadCmd)
  call setqflist([], 'a', {'idx': s:current_file_idx + 1})
endfunction

" Sync s:current_file_idx from buffer name (called on BufEnter)
function! ghreview#sync_file_idx() abort
  if s:showing_file || empty(s:diff_files)
    return
  endif

  let bufname = expand('%')
  let filename = substitute(bufname, '^ghreview://diff/', '', '')

  let idx = 0
  for file in s:diff_files
    if file.filename == filename
      let s:current_file_idx = idx
      return
    endif
    let idx += 1
  endfor
endfunction

function! ghreview#refresh_diff() abort
  " Skip if we're already in the process of showing a file (avoid recursion)
  if s:showing_file
    return
  endif

  if empty(s:diff_files)
    echo 'No diff loaded'
    return
  endif

  " Sync file index from buffer name
  call ghreview#sync_file_idx()

  call s:show_current_file()
endfunction

function! ghreview#close_diff() abort
  " Clear state before deleting buffer to avoid autocmd issues
  let s:current_pr = {}
  let s:diff_files = []
  " Clear qflist
  call setqflist([], 'r')
  cclose
  " Use noautocmd to prevent BufDelete autocmds (e.g., LSP) from firing on fake buffer
  noautocmd bwipeout!
endfunction

" Show comments
function! ghreview#comments() abort
  if !has_key(s:current_pr, 'number')
    echoerr 'No PR selected. Use :PRDiff first.'
    return
  endif

  let repo = s:get_repo()
  if repo == ''
    return
  endif

  echo 'Fetching comments...'
  call s:send_request('pr/comments', {'repo': repo, 'number': s:current_pr.number}, function('s:on_pr_comments'))
endfunction

function! s:on_pr_comments(result) abort
  if a:result == v:null
    echo 'Failed to get comments'
    return
  endif

  let bufname = 'ghreview://comments'
  let bufnr = bufnr(bufname)
  if bufnr == -1
    execute 'new ' . bufname
  else
    execute 'buffer ' . bufnr
  endif

  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal nowrap
  setlocal filetype=ghreview-comments

  setlocal modifiable
  silent! %delete _

  call append(0, '# Comments for PR #' . a:result.number)
  call append(1, '')

  let line = 2

  " Review comments (inline)
  if len(a:result.review_comments) > 0
    call append(line, '## Review Comments')
    let line += 1
    call append(line, '')
    let line += 1

    for comment in a:result.review_comments
      call append(line, '--- ' . comment.path . ':' . comment.line . ' by ' . comment.author . ' (' . comment.created_at . ')')
      let line += 1
      for bodyline in split(comment.body, '\n')
        call append(line, '    ' . bodyline)
        let line += 1
      endfor
      call append(line, '')
      let line += 1
    endfor
  endif

  " Issue comments (general)
  if len(a:result.issue_comments) > 0
    call append(line, '## General Comments')
    let line += 1
    call append(line, '')
    let line += 1

    for comment in a:result.issue_comments
      call append(line, '--- ' . comment.author . ' (' . comment.created_at . ')')
      let line += 1
      for bodyline in split(comment.body, '\n')
        call append(line, '    ' . bodyline)
        let line += 1
      endfor
      call append(line, '')
      let line += 1
    endfor
  endif

  if len(a:result.review_comments) == 0 && len(a:result.issue_comments) == 0
    call append(line, 'No comments yet.')
  endif

  setlocal nomodifiable
  call cursor(1, 1)
  redraw
  echo 'Loaded ' . len(a:result.review_comments) . ' review comments and ' . len(a:result.issue_comments) . ' general comments'
endfunction

function! ghreview#goto_comment() abort
  let line = getline('.')
  let matches = matchlist(line, '^--- \([^:]\+\):\(\d\+\)')
  if len(matches) < 3
    return
  endif

  let filepath = matches[1]
  let linenum = str2nr(matches[2])

  " Try to open the file
  if filereadable(filepath)
    execute 'edit ' . fnameescape(filepath)
    call cursor(linenum, 1)
  else
    echo 'File not found: ' . filepath
  endif
endfunction

" Open file at line from diff view
function! ghreview#open_file_at_line() abort
  if s:current_file_idx >= len(s:diff_files)
    echo 'No file selected'
    return
  endif

  let cursor_line = line('.')
  let linenum = s:get_diff_line_number(cursor_line)

  if linenum <= 0
    echo 'Cannot determine line number - place cursor on a code line'
    return
  endif

  let file = s:diff_files[s:current_file_idx]
  let filepath = file.filename

  if filereadable(filepath)
    execute 'edit ' . fnameescape(filepath)
    call cursor(linenum, 1)
    normal! zz
  else
    echo 'File not found: ' . filepath
  endif
endfunction

" Add a comment
" When called with a range (visual selection), pre-fill with GitHub suggestion
function! ghreview#add_comment(has_range, line1, line2) abort
  if !has_key(s:current_pr, 'number')
    echoerr 'No PR selected. Use :PRDiff first.'
    return
  endif

  if s:current_file_idx >= len(s:diff_files)
    echoerr 'No file selected'
    return
  endif

  " Get line numbers from the diff
  let cursor_line = a:has_range ? a:line2 : line('.')
  let diff_line = s:get_diff_line_number(cursor_line)

  if diff_line <= 0
    echoerr 'Cannot add comment here - place cursor on a code line in the diff'
    return
  endif

  " For multi-line selection, also get the start line
  let start_line = 0
  if a:has_range && a:line1 != a:line2
    let start_line = s:get_diff_line_number(a:line1)
  endif

  let file = s:diff_files[s:current_file_idx]

  " Store pending comment info
  let s:pending_comment = {
        \ 'path': file.filename,
        \ 'line': diff_line,
        \ 'start_line': start_line,
        \ }

  " Get selected text for suggestion if range was given
  let suggestion_lines = []
  if a:has_range
    let selected = getline(a:line1, a:line2)
    for sline in selected
      " Strip the diff prefix (+, -, space) from each line
      if sline =~ '^[+ ]'
        call add(suggestion_lines, sline[1:])
      elseif sline !~ '^-'
        " Keep lines that don't start with diff markers as-is
        call add(suggestion_lines, sline)
      endif
      " Skip removed lines (starting with -)
    endfor
  endif

  " Open comment edit buffer
  let bufname = 'ghreview://comment-edit'
  execute 'belowright 10new ' . bufname

  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal filetype=ghreview-comment-edit

  call append(0, '# Comment on ' . file.filename . ':' . diff_line)
  call append(1, '# Press <leader>cs to submit, q to cancel')
  call append(2, '')

  " Pre-fill with GitHub suggestion if we have selected text
  if len(suggestion_lines) > 0
    call append(3, '```suggestion')
    let line = 4
    for sline in suggestion_lines
      call append(line, sline)
      let line += 1
    endfor
    call append(line, '```')
    call cursor(5, 1)
  else
    call cursor(3, 1)
    startinsert
  endif
endfunction

function! s:get_diff_line_number(cursor_line) abort
  " Parse the diff to find the actual line number
  " Look for @@ -a,b +c,d @@ patterns and count lines
  let lines = getbufline('%', 1, a:cursor_line)
  let current_line = 0

  for line in lines
    " Check for hunk header
    let matches = matchlist(line, '^@@ -\d\+\(,\d\+\)\? +\(\d\+\)')
    if len(matches) >= 3
      let current_line = str2nr(matches[2]) - 1
      continue
    endif

    " Skip header lines
    if line =~ '^#' || line == ''
      continue
    endif

    " Count lines (but not removed lines)
    if line !~ '^-'
      let current_line += 1
    endif
  endfor

  return current_line
endfunction

function! ghreview#submit_comment() abort
  if empty(s:pending_comment)
    echoerr 'No pending comment'
    return
  endif

  " Get comment body (skip header lines)
  let lines = getline(3, '$')
  let body = join(lines, "\n")
  let body = trim(body)

  if body == ''
    echoerr 'Comment cannot be empty'
    return
  endif

  let repo = s:get_repo()
  if repo == ''
    return
  endif

  let params = {
        \ 'repo': repo,
        \ 'number': s:current_pr.number,
        \ 'path': s:pending_comment.path,
        \ 'line': s:pending_comment.line,
        \ 'body': body,
        \ }

  if has_key(s:pending_comment, 'start_line') && s:pending_comment.start_line > 0
    let params.start_line = s:pending_comment.start_line
  endif

  echo 'Submitting comment...'
  call s:send_request('pr/add_comment', params, function('s:on_comment_added'))
endfunction

function! s:on_comment_added(result) abort
  let s:pending_comment = {}

  " Close the comment edit buffer
  let bufnr = bufnr('ghreview://comment-edit')
  if bufnr != -1
    execute 'bdelete! ' . bufnr
  endif

  if a:result == v:null
    echoerr 'Failed to add comment'
    return
  endif

  echo 'Comment added successfully!'
endfunction

" Submit a review
function! ghreview#review(...) abort
  if !has_key(s:current_pr, 'number')
    echoerr 'No PR selected. Use :PRDiff first.'
    return
  endif

  let event = a:0 > 0 && a:1 != '' ? toupper(a:1) : ''

  if event == ''
    " Show menu
    echo 'Review type:'
    echo '  1. APPROVE'
    echo '  2. REQUEST_CHANGES'
    echo '  3. COMMENT'
    let choice = input('Select (1-3): ')
    if choice == '1'
      let event = 'APPROVE'
    elseif choice == '2'
      let event = 'REQUEST_CHANGES'
    elseif choice == '3'
      let event = 'COMMENT'
    else
      echo "\nCancelled"
      return
    endif
  endif

  " Validate event
  if index(['APPROVE', 'REQUEST_CHANGES', 'COMMENT'], event) == -1
    echoerr 'Invalid review type: ' . event
    return
  endif

  let body = input("\nReview comment (optional): ")

  let repo = s:get_repo()
  if repo == ''
    return
  endif

  let params = {
        \ 'repo': repo,
        \ 'number': s:current_pr.number,
        \ 'event': event,
        \ 'body': body,
        \ }

  echo "\nSubmitting review..."
  call s:send_request('pr/submit_review', params, function('s:on_review_submitted'))
endfunction

function! s:on_review_submitted(result) abort
  if a:result == v:null
    echoerr 'Failed to submit review'
    return
  endif

  echo 'Review submitted: ' . a:result.state
endfunction
