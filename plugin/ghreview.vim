" ghreview.vim - GitHub PR Review plugin for Vim
" Maintainer: Tom Bruyelle
" Version: 1.0

if exists('g:loaded_ghreview')
  finish
endif
let g:loaded_ghreview = 1

" Configuration
if !exists('g:ghreview_binary')
  let gopath = exists('$GOPATH') && $GOPATH != '' ? $GOPATH : expand('~/go')
  let g:ghreview_binary = gopath . '/bin/ghreview'
endif

" Commands
command! -nargs=? PRList call ghreview#list(<q-args>)
command! -nargs=? PRDiff call ghreview#diff(<args>)
command! PRComments call ghreview#comments()
command! -range PRComment call ghreview#add_comment(<range>, <line1>, <line2>)
command! -nargs=? PRReview call ghreview#review(<q-args>)
command! PRSuggest call ghreview#suggest_changes()

" Keymaps for PR buffers (set in ftplugin or after buffer creation)
augroup ghreview
  autocmd!
  " Intercept :e on ghreview:// buffers to refresh instead of clearing
  autocmd BufReadCmd ghreview://diff/* call ghreview#refresh_diff()
  " Sync file index when entering a diff buffer (for :cnext/:cprev support)
  autocmd BufEnter ghreview://diff/* call ghreview#sync_file_idx()
  " Keymaps for PR buffers
  autocmd FileType ghreview-list nnoremap <buffer> <CR> :call ghreview#open_pr_under_cursor()<CR>
  autocmd FileType ghreview-list nnoremap <buffer> q :bdelete<CR>
  autocmd FileType ghreview-diff nnoremap <buffer> <C-n> :call ghreview#next_file()<CR>
  autocmd FileType ghreview-diff nnoremap <buffer> <C-m> :call ghreview#prev_file()<CR>
  autocmd FileType ghreview-diff nnoremap <buffer> q :call ghreview#close_diff()<CR>
  autocmd FileType ghreview-diff nnoremap <buffer> <leader>cc :PRComment<CR>
  autocmd FileType ghreview-diff xnoremap <buffer> <leader>cc :PRComment<CR>
  autocmd FileType ghreview-diff nnoremap <buffer> o :call ghreview#open_file_at_line()<CR>
  autocmd FileType ghreview-diff nnoremap <buffer> <leader>cr :PRReview<CR>
  autocmd FileType ghreview-comments nnoremap <buffer> <CR> :call ghreview#goto_comment()<CR>
  autocmd FileType ghreview-comments nnoremap <buffer> q :bdelete<CR>
  autocmd FileType ghreview-comment-edit nnoremap <buffer> <leader>cs :call ghreview#submit_comment()<CR>
  autocmd FileType ghreview-comment-edit nnoremap <buffer> <leader>cn :call ghreview#suggest_skip()<CR>
  autocmd FileType ghreview-comment-edit nnoremap <buffer> q :call ghreview#suggest_abort()<CR>
augroup END
