# Vim RBQL JSON - Experimental plugin

## Disclaimer
This is an experimental POC plugin to test feasibility of using RBQL with JSON files.  
Use at your own risk!  

## Description
Experimental POC Vim plugin to run RBQL queries for JSON files.  
This plugin provides a single command `:Select` which only works for JSON files with `json` filetype.  
Run `:set ft=json` to ensure that the current file has "json" filetype.  

Example:  
```
:SELECT a['name'], a['occupation'] ORDER BY a['name']
```

To learn more about RBQL, see https://github.com/mechatroner/RBQL

## Settings
* To configure pretty print indent run `:let g:rb_json_pretty_indent=4`

