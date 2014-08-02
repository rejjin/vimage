set lib_file  [file join $dir TkImageTools[info sharedlibextension]]
if { [file exist $lib_file] } {
package ifneeded TkImageTools 1.0 [list load $lib_file]
}
