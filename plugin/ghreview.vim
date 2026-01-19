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
command! -nargs=1 PRDiff call ghreview#diff(<args>)
command! PRComments call ghreview#comments()
command! PRComment call ghreview#add_comment()
command! -nargs=? PRReview call ghreview#review(<q-args>)

" Keymaps for PR buffers (set in ftplugin or after buffer creation)
augroup ghreview
  autocmd!
  autocmd FileType ghreview-list nnoremap <buffer> <CR> :call ghreview#open_pr_under_cursor()<CR>
  autocmd FileType ghreview-list nnoremap <buffer> q :bdelete<CR>
  autocmd FileType ghreview-diff nnoremap <buffer> ]f :call ghreview#next_file()<CR>
  autocmd FileType ghreview-diff nnoremap <buffer> [f :call ghreview#prev_file()<CR>
  autocmd FileType ghreview-diff nnoremap <buffer> q :call ghreview#close_diff()<CR>
  autocmd FileType ghreview-diff nnoremap <buffer> <leader>cc :PRComment<CR>
  autocmd FileType ghreview-comments nnoremap <buffer> <CR> :call ghreview#goto_comment()<CR>
  autocmd FileType ghreview-comments nnoremap <buffer> q :bdelete<CR>
  autocmd FileType ghreview-comment-edit nnoremap <buffer> <leader>cs :call ghreview#submit_comment()<CR>
  autocmd FileType ghreview-comment-edit nnoremap <buffer> q :bdelete!<CR>
augroup END
