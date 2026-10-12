"==============================================================================
"
" Description: Vim RBQL JSON
" Authors: Dmitry Ignatovich, ...
"
"==============================================================================

command! -buffer -nargs=+ Select call vim_rbql_json#run_select_cmd_query(<q-args>)
