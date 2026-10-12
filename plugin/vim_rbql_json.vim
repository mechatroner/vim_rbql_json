"==============================================================================
"
" Description: Vim RBQL JSON
" Authors: Dmitry Ignatovich, ...
"
"==============================================================================

augroup VimRbqlJsonInitAuGrp
    autocmd!
    autocmd FileType json command! -nargs=+ Select call vim_rbql_json#run_select_cmd_query(<q-args>)
augroup END
