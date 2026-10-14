"==============================================================================
"
" Description: Vim RBQL JSON
" Authors: Dmitry Ignatovich, ...
"
"==============================================================================

let s:rb_storage_dir = exists('g:rb_storage_dir') ? g:rb_storage_dir : $HOME . '/.rainbow_csv_storage'
let s:script_folder_path = expand('<sfile>:p:h:h')
let s:python_env_initialized = 0

func! s:get_pretty_indent()
    " g:rb_json_pretty_indent must be an integer.
    return exists('g:rb_json_pretty_indent') ? g:rb_json_pretty_indent : 0
endfunc

function! s:py_source_escape(src)
    " Strings in 'substitute' must follow esoteric rules, see `:help substitute()`
    let dst = substitute(a:src, '\\', '\\\\', "g")
    let dst = substitute(dst, '\t', '\\t', "g")
    let dst = substitute(dst, '"', '\\"', "g")
    return dst
endfunc

function! s:EnsureJavaScriptInitialization()
    if (s:js_env_initialized)
        return 1
    endif
    let js_version = tolower(system('node --version'))
    if (v:shell_error != 0)
        return 0
    endif
    let s:js_env_initialized = 1
    return 1
endfunction


func! vim_rbql_json#parse_report(report_content)
    let lines = split(a:report_content, '\r\?\n')
    let psv_warning_report = ''
    let psv_error_report = ''
    let psv_query_status = (len(lines) > 0 && len(lines[0]) > 0) ? lines[0] : 'Unknown error'
    let psv_dst_table_path = len(lines) > 1 ? lines[1] : ''
    let report = join(lines[2:], "\n")
    if psv_query_status == "OK"
        let psv_warning_report = report
    else
        let psv_error_report = report
    endif
    return [psv_query_status, psv_error_report, psv_warning_report, psv_dst_table_path]
endfunc


func! s:ShowImportantMessage(msg_header, msg_lines)
    echohl ErrorMsg
    echomsg a:msg_header
    echohl None
    for msg in a:msg_lines
        echomsg msg
    endfor
    call input("Press ENTER to continue...")
endfunc


function! s:EnsurePythonInitialization()
    if (s:python_env_initialized)
        return 1
    endif
    let py_home_dir = s:script_folder_path . '/rbql_core'
    let py_home_dir = s:py_source_escape(py_home_dir)
    if has("python3") && !s:use_system_python()
        py3 import sys
        py3 import vim
        exe 'python3 sys.path.insert(0, "' . py_home_dir . '")'
        py3 import vim_rbql
    else
        call vim_rbql_json#find_python_interpreter()
        if s:system_python_interpreter == ""
            return 0
        endif
    endif
    let s:python_env_initialized = 1
    return 1
endfunction


func! vim_rbql_json#find_python_interpreter()
    let py3_version = tolower(system('python3 --version'))
    if (v:shell_error == 0 && match(py3_version, 'python 3\.') == 0)
        let s:system_python_interpreter = 'python3'
        return s:system_python_interpreter
    endif
    let s:system_python_interpreter = ''
    return s:system_python_interpreter
endfunc



func! s:ensure_storage_exists()
    if !isdirectory(s:rb_storage_dir)
        call mkdir(s:rb_storage_dir, "p")
    endif
endfunc

func! s:get_rb_script_path_for_this_table()
    let rb_script_name = expand("%:t") . ".rbql"
    call s:ensure_storage_exists()
    let rb_script_path = s:rb_storage_dir . '/' . rb_script_name
    return rb_script_path
endfunc


func! s:get_meta_language()
    let lang_lw = 'python'
    if exists("g:rbql_meta_language")
        let lang_lw = tolower(g:rbql_meta_language)
    endif
    if exists("g:rbql_backend_language")
        let lang_lw = tolower(g:rbql_backend_language)
    endif
    if lang_lw == 'javascript'
        let lang_lw = 'js'
    endif
    return lang_lw
endfunc


func! s:converged_select(table_buf_number, rb_script_path, query_buf_nr)
    let meta_language = s:get_meta_language()

    if meta_language == "python" && !s:EnsurePythonInitialization()
        echoerr "Python interpreter not found. Unable to run in this mode."
        return 0
    endif

    if meta_language == "js"
        " TODO Support JS
        echoerr "This is an experimental plugin so JS mode is currently not supported but it is easy to add it."
        return 0
    endif

    if meta_language == "js" && !s:EnsureJavaScriptInitialization()
        echoerr "Node.js interpreter not found. Unable to run in this mode."
        return 0
    endif

    let rbql_encoding = 'utf-8'

    let table_path = expand("#" . a:table_buf_number . ":p")
    if table_path == ""
        " For unnamed buffers. E.g. can happen for stdin-read buffer: `cat data.tsv | vim -`
        let tmp_file_name = "tmp_table_" .  strftime("%Y_%m_%d_%H_%M_%S") . ".txt"
        let table_path = s:rb_storage_dir . "/" . tmp_file_name
        execute "w " . table_path
    endif
    let table_path_esc = s:py_source_escape(table_path)
    let rb_script_path_esc = s:py_source_escape(a:rb_script_path)

    let psv_query_status = 'Unknown error'
    let psv_error_report = 'Something went wrong'
    let psv_warning_report = ''
    let psv_dst_table_path = ''
    let pretty_indent = s:get_pretty_indent()

    redraw!
    echo "executing..."
    let py_call = 'vim_rbql.run_execute("' . table_path_esc . '", "' . rb_script_path_esc . '", ' . pretty_indent . ')'
    if meta_language == "js"
        let rbql_executable_path = s:script_folder_path . '/rbql_core/vim_rbql.js'
        let cmd_args = ['node', shellescape(rbql_executable_path), shellescape(table_path), shellescape(a:rb_script_path), shellescape(pretty_indent)]
        let cmd = join(cmd_args, ' ')
        let report_content = system(cmd)
        let [psv_query_status, psv_error_report, psv_warning_report, psv_dst_table_path] = vim_rbql_json#parse_report(report_content)
    elseif s:system_python_interpreter != ""
        let rbql_executable_path = s:script_folder_path . '/rbql_core/vim_rbql.py'
        let cmd_args = [s:system_python_interpreter, shellescape(rbql_executable_path), shellescape(table_path), shellescape(a:rb_script_path), shellescape(pretty_indent)]
        let cmd = join(cmd_args, ' ')
        let report_content = system(cmd)
        let [psv_query_status, psv_error_report, psv_warning_report, psv_dst_table_path] = vim_rbql_json#parse_report(report_content)
    elseif has("python3")
        exe 'python3 ' . py_call
    else
        call s:ShowImportantMessage("Error", ["Python not found, vim must have 'python' or 'python3' feature installed to run in this mode"])
        return 0
    endif

    if psv_query_status != "OK"
        call s:ShowImportantMessage(psv_query_status, [psv_error_report])
        return 0
    endif

    if a:query_buf_nr != -1
        execute "bd! " . a:query_buf_nr
    endif

    execute "e " . fnameescape(psv_dst_table_path)

    let b:self_path = psv_dst_table_path
    let b:root_table_buf_number = a:table_buf_number
    let b:root_table_name = fnamemodify(table_path, ":t")
    let b:self_buf_number = bufnr("%")
    call setbufvar(a:table_buf_number, 'selected_buf', b:self_buf_number)
    set ft=json


    if len(psv_warning_report)
        let warnings = split(psv_warning_report, "\n")
        for wnum in range(len(warnings))
            let warnings[wnum] = 'Warning: ' . warnings[wnum]
        endfor
        call s:ShowImportantMessage("Completed with WARNINGS!", warnings)
    endif
    return 1
endfunc


func! s:run_cmd_query(query)
    let rb_script_path = s:get_rb_script_path_for_this_table()
    call writefile([a:query], rb_script_path)
    let table_buf_number = bufnr("%")
    call s:converged_select(table_buf_number, rb_script_path, -1)
endfunction


func! vim_rbql_json#run_select_cmd_query(query_string)
    let query = 'SELECT ' . a:query_string
    "echomsg 'In vim rbql json: ' . query
    call s:run_cmd_query(query)
endfunction
