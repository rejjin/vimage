option add *Viewer*Panedwindow.ShowHandle 1 widgetDefault
option add *Viewer*Panedwindow.HandleSize 6 widgetDefault
option add *Viewer*Panedwindow.SashPad 2 widgetDefault
option add *Viewer*Labelframe.padX 3 widgetDefault
option add *Viewer*Labelframe.padY 3 widgetDefault
option add *Viewer*Scrollbar.Width 10 widgetDefault
option add *Viewer*Listbox.Width 20 widgetDefault
option add *Viewer*Listbox.HighlightColor gray widgetDefault
option add *Viewer*Label.Anchor center widgetDefault
option add *Viewer*Label.Relief flat widgetDefault

option add *Canvas.uwp_grab_scroller_grab_cursor fleur
option add *Canvas.uwp_grab_scroller_ungrab_cursor hand2
 
bind GrabScroller <ButtonPress-1> { ::viewer::uwp_grab_scroller_event_press %W %x %y }
bind GrabScroller <ButtonRelease-1> { ::viewer::uwp_grab_scroller_event_release %W }
bind GrabScroller <Enter> { ::viewer::uwp_grab_scroller_event_enter %W }
bind GrabScroller <Leave> { ::viewer::uwp_grab_scroller_event_leave %W }
bind GrabScrollerScroll <Motion> { ::viewer::uwp_grab_scroller_event_motion %W %x %y }
	
namespace eval ::viewer {
variable default
variable system

	set system(script_dir) 				[file dirname [info script]]
	set system(version)					0.1
	set system(library_dir)				[file normalize $system(script_dir)]
	
	set default(-position) 							center
	set default(-alpha) 								-1
	set default(-topmost) 							0
	set default(-size) 								default
	set default(-scroller_gain)					sticky_mouse
	set default(-startup_history_state)		1
	
	set default(-show_viewer_command) 		""
	set default(-hide_viewer_command) 			""
	set default(-add_image_command) 			""
	
	package require msgcat
	::msgcat::mcload [file join $system(script_dir) msgs]
	
	package provide viewer $system(version)
}

proc ::viewer::viewer {self args} {
	eval OptionsInit $self $args
	NewWidget $self
	CommandInit $self
	
	return $self
}

proc ::viewer::OptionsInit {self args} {
variable default
variable system

	upvar #0 [namespace current]::$self state
	
	foreach {Dtag Dvalue} [array get default] {
	set state($Dtag) $Dvalue
	}
	
	foreach {Atag Avalue} $args {
		switch -- $Atag {
			-position {
				if {![regexp {^\+[[:digit:]]+\+[[:digit:]]+$} $Avalue] && \
					![string equal -nocase $Avalue "center"]} {
						return -code error "bad position \"$Avalue\": must be\
							\"+INTEGER+INTEGER\" or center"
				} else {set state(-position) [string tolower $Avalue]}
			}
			-topmost {
				if {![string is boolean $Avalue]} {
						return -code error "Avalue for \"-topmost\" must be a boolean"
				} else {set state(-topmost) [expr {$Avalue ? 1 : 0}]}
			}
			-alpha {
				if {[string is boolean $Avalue] && [string is false $Avalue]} {
					set set state(-alpha) -1
				} elseif {![string is integer -strict $Avalue]} {
					return -code error "bad alpha Avalue \"$Avalue\": must be INTEGER or FALSE"
				} elseif {($Avalue < 0) && ($Avalue > 100)} {
					return -code error "Avalue for alpha must be a 100 maximum and 0 minimum"
				} else {set state(-alpha) [expr {$Avalue / 100.0}]}
			}
			-size {
				if {[string equal -nocase $Avalue "default"]} {
					set state(-size) "default"
				} elseif {[regexp {^([[:digit:]]+)x([[:digit:]]+)$} $Avalue {} x y]} {
					set state(-size) ${x}x${y}
				} else {
					return -code error "bad size \"$Avalue\": must be\
						\"INTEGERxINTEGER\" or \"default\""
				}
			}
			-scroller_gain {
				if {[string equal -nocase $Avalue "sticky_mouse"]} {
					set state(-scroller_gain) sticky_mouse
				} elseif {[string equal -nocase $Avalue "quick_scroll"]} {
					set state(-scroller_gain) quick_scroll
				} else {
					return -code error "bad scroller gain value \"$Avalue\": must be\
							\"sticky_mouse\" or \"quick_scroll\""
				}
			}
			-startup_history_state {
				if {[string is boolean $Avalue]} {
					set state(-startup_history_state) $Avalue
				} else {
					return -code error "Avalue for \"-startup_history_state\"\
						must be a boolean"
				}
			}
			-show_viewer_command {
				set state(-show_viewer_command) $Avalue
			}
			-hide_viewer_command {
				set state(-hide_viewer_command) $Avalue
			}
			-add_image_command {
				set state(-add_image_command) $Avalue
			}
			default {
				return -code error "bad option name $Atag: must be\
					-position, -topmost, -alpha, -scroller_gain, -startup_history_state,\
					-size, -show_viewer_command, -hide_viewer_command\
					or -add_image_command"
			}
		}
	}
}

proc ::viewer::CommandInit {self} {
	interp hide {} $self
    interp alias {} $self {} [namespace origin Commands] $self
    return $self
}

proc ::viewer::NewWidget {self} {
variable system
	
	upvar #0 [set State [namespace current]::$self] state
	
	if {[winfo exist $self]} {
		unset $State
		return -code error "window name \"$self\"\
			already exists in parent"
	}
	
	toplevel $self -class Viewer
	
	wm title $self [::msgcat::mc "Image viewer"]
	wm iconname $self "imgviewer"
	wm protocol $self WM_DELETE_WINDOW [list [namespace origin Quit] $self]
	
	CatchAttribute -topmost $self $state(-topmost)
	CatchAttribute -alpha $self $state(-alpha)
	
	panedwindow $self.panel -orient horizontal

	labelframe $self.panel.history -text [::msgcat::mc "History"] 
	scrollbar $self.panel.history.yscroll -command "$self.panel.history.list yview"
	scrollbar $self.panel.history.xscroll -orient horizontal -command "$self.panel.history.list xview"
	listbox $self.panel.history.list -setgrid 1 -activestyle none \
		-yscroll "$self.panel.history.yscroll set" -xscroll "$self.panel.history.xscroll set"

	labelframe $self.panel.view

    scrollbar $self.panel.view.xscroll -orient horizontal \
		-command "$self.panel.view.canvas xview"
    scrollbar $self.panel.view.yscroll  -command "$self.panel.view.canvas yview"
    canvas $self.panel.view.canvas -relief sunken -borderwidth 1 \
		-xscrollcommand "$self.panel.view.xscroll set" \
		-yscrollcommand "$self.panel.view.yscroll set"

    $self.panel.view.canvas create image 0 0 -image {} -tag IMG

    $self.panel.view.canvas configure -scrollregion [$self.panel.view.canvas bbox all]
	
	pack $self.panel.history.yscroll -fill y -side right
	pack $self.panel.history.list -fill both -expand 1 -side left
	pack $self.panel.history.xscroll -fill x -side bottom -after $self.panel.history.yscroll
	pack $self.panel.view.xscroll -side bottom -fill x
	pack $self.panel.view.yscroll  -side right  -fill y
	pack $self.panel.view.canvas -side right  -fill both  -expand 1
 
	frame $self.bbox -class Bbox
	
    button $self.bbox.free -text [::msgcat::mc "Free memory"] \
        -relief groove -command [list [namespace origin free_all] $self]
        
	menubutton $self.bbox.action -text [::msgcat::mc "Zoom"] \
		-menu $self.bbox.action.menu \
		-relief groove
	
	menu $self.bbox.action.menu -tearoff 0 
	$self.bbox.action.menu add command -label [::msgcat::mc "Zoom in"] \
		-command [list [namespace origin ImageScale] $self 2]
	$self.bbox.action.menu add command -label [::msgcat::mc "Normal"] \
		-command [list [namespace origin ImageScale] $self normal]
	$self.bbox.action.menu add command -label [::msgcat::mc "Zoom out"] \
		-command [list [namespace origin ImageScale] $self 0.5]
		
	button $self.bbox.hideall -text [::msgcat::mc "Hide all"]  -relief groove \
		-command [list [namespace origin ToggleAllGroups] $self hide]
	button $self.bbox.showall -text [::msgcat::mc "Show all"] -relief groove\
		-command [list [namespace origin ToggleAllGroups] $self show]
	button $self.bbox.back -text [::msgcat::mc "Back"] -relief groove \
		-command [list [namespace origin ChangeState] $self hide]
	button $self.bbox.toggle -text [::msgcat::mc "Toggle history"] \
	-command [list [namespace origin ToggleHistory] $self] -relief groove
	 button $self.bbox.save -text [::msgcat::mc "Save image"] \
	-command [list [namespace origin SaveImage] $self] -relief groove
	 
	pack $self.bbox.back $self.bbox.toggle $self.bbox.save \
		$self.bbox.showall $self.bbox.hideall $self.bbox.action $self.bbox.free \
				-padx 3 -pady 2 -anchor w -side right
	
	$self.panel add $self.panel.history
	$self.panel add $self.panel.view
	
	pack $self.panel -fill both -expand 1 -pady 2
	pack $self.bbox -side bottom -after $self.panel -fill x -expand 0
	
	SetSize $self $state(-size)
	PlaceWindow $self $state(-position)
	
	set state(listbox) $self.panel.history.list
	set state(canvas) $self.panel.view.canvas
	set state(header) $self.panel.view
	set state(hidden) {}
	set state(last) {}
	set state(historystate) 1
	
	uwp_grab_scroller_bind $self.panel.view.canvas
	
	bind $state(listbox) <1> [list [namespace origin See] $self "@%x,%y"]
	bind $state(listbox) <3> [list [namespace origin ToggleGroup] $self "@%x,%y"]
	bind $state(canvas) <3> [list [namespace origin CanvasMenu] $self]
	bind $self <Double-1> [list [namespace origin ChangeScreenSize] $self]
	bind $self <Escape> [list [namespace origin Quit] $self]
	bind $self <space> [list [namespace origin ToggleHistory] $self]
	bind $self <Destroy> "+unset -nocomplain [namespace current]::%W"
	
	ToggleHistory $self $state(-startup_history_state)
	ChangeState $self hide
}

proc ::viewer::SetImage {self image_id} {

	upvar #0 [namespace current]::$self state
	
	$state(canvas) itemconfigure IMG -image $image_id
	$state(canvas) configure -scrollregion [$state(canvas) bbox all]
}

proc ::viewer::GetCurrentImage {self} {

	upvar #0 [namespace current]::$self state
	
	$state(canvas) itemconfigure IMG -image $image_id
	$state(canvas) configure -scrollregion [$state(canvas) bbox all]
}

proc ::viewer::SetHeader {self text} {

	upvar #0 [namespace current]::$self state
	
	$state(header) configure -text $text
}

proc ::viewer::Add {self groupname inserttext imageid data} {

	upvar #0 [namespace current]::$self state
	
	if {[string length $state(-add_image_command)] > 0} {
		set func [lindex $state(-add_image_command) 0]
		set cargs [lrange $state(-add_image_command) 1 end]
		set code [catch { eval $func $cargs } state]
		
		if {$code == 1} {
		::bgerror [format "Procedure %s returned code\
			%s\n%s" $func $code $state]
		return
		}
		
		if {$code == 3 || ($code == 0 && [string equal $state stop])} {
			return
		}
	}
	
	if {[info exist state(groups,$groupname)]} {
		if {[lsearch -exact $state(groups,$groupname) $inserttext] < 0} {
			lappend state(groups,$groupname) $inserttext
		}
	} else {
		set state(groups,$groupname) $inserttext
	}
	
	set state(image,$inserttext) $imageid
	set state(data,$inserttext) $data
	set state(group,$inserttext) $groupname
	set state(inserttext,$imageid) $inserttext
	set state(last) $inserttext
	
	HistoryRedraw $self $inserttext
}

proc ::viewer::Commands {self cmd args} {

	switch -exact -- $cmd {
		add {
			return [uplevel 1 [list [namespace origin Add] $self] $args]
		}
		hide {
			return [uplevel 1 [list [namespace origin ChangeState] $self hide]]
		}
		show {
			return [uplevel 1 [list [namespace origin ChangeState] $self show]]
		}
		see {
			return [uplevel 1 [list [namespace origin See] $self] $args]
		}
		configure {
			return [uplevel 1 [list [namespace origin Configure] $self] $args]
		}
		cget {
			return [uplevel 1 [list [namespace origin Cget] $self] $args]
		}
		toggle {
			return [uplevel 1 [list [namespace origin ToggleHistory] $self]]
		}
	}
}

proc ::viewer::Cget {self args} {
variable default
	
	upvar #0 [namespace current]::$self state
	
	if {[llength $args] != 1} {
	return -code error "wrong # args: should be \"$self cget option\""
	}
	
	foreach option [array names default -*] {
		if {[string equal $args $option]} {
			return $state($option)
		}
	}
	
	return -code error "bad option name $args: must be\
		-position, -topmost, -alpha, -scroller_gain, -startup_history_state,\
		-size, -show_viewer_command, -hide_viewer_command\
		or -add_image_command"
}

proc ::viewer::Configure {self args} {
variable default
	upvar #0 [namespace current]::$self state
	
	set result ""
	if {[llength $args] == 0} {
		foreach option [array names default -*] {
			append result "[list $option $state($option)] "
		}
		return [string range $result 0 end-1]
	} elseif {[llength $args] == 1} {
		return [Cget $self $args]
	}
	
	foreach {option value} $args {
		switch -exact -- $option {
			-position {
				if {![regexp {^\+[[:digit:]]+\+[[:digit:]]+$} $value] && \
					![string equal -nocase $value "center"]} {
						return -code error "bad position \"$value\": must be\
							\"+INTEGER+INTEGER\" or center"
				} else {
					set state(-position) [string tolower $value]
					PlaceWindow $self $state(-position)
				}
			}
			-topmost {
				if {![string is boolean $value]} {
						return -code error "value for \"-topmost\" must be a boolean"
				} else {
					set state(-topmost) [expr {$value ? 1 : 0}]
					CatchAttribute -topmost $self $state(-topmost)
				}
			}
			-alpha {
				if {[string is boolean $value] && [string is false $value]} {
					set state(-alpha) -1
				} elseif {![string is integer -strict $value]} {
					return -code error "bad alpha value \"$value\": must be INTEGER or FALSE"
				} elseif {($value < 0) && ($value > 100)} {
					return -code error "value for alpha must be a 100 maximum and 0 minimum"
				} else {
					set state(-alpha) [expr {$value / 100.0}]
					CatchAttribute -alpha $self $state(-alpha)
				}
			}
			-size {
				if {[string equal -nocase $value "default"]} {
					set state(-size) default
					SetSize $self $state(-size)
				} elseif {[regexp {^([[:digit:]]+)x([[:digit:]]+)$} $value {} x y]} {
					set state(-size) ${x}x${y}
					SetSize $self $state(-size)
				} else {
					return -code error "bad size \"$value\": must be\
						\"INTEGERxINTEGER\""
				}
			}
			-scroller_gain {
				if {[string equal -nocase $value "sticky_mouse"]} {
					set state(-scroller_gain) sticky_mouse
				} elseif {[string equal -nocase $value "quick_scroll"]} {
					set state(-scroller_gain) quick_scroll
				} else {
					return -code error "bad scroller gain value \"$value\": must be\
							\"sticky_mouse\" or \"quick_scroll\""
				}
			}
			-startup_history_state {
				if {[string is boolean $value]} {
					set state(-startup_history_state) $value
				} else {
					return -code error "Value for \"-startup_history_state\"\
					must be a boolean"
				}
			}
			-show_viewer_command {
				set state(-show_viewer_command) $value
			}
			-hide_viewer_command {
				set state(-hide_viewer_command) $value
			}
			-add_image_command {
				set state(-add_image_command) $value
			}
			default {
				return -code error "bad option name $option: must be\
					-position, -topmost, -alpha, -scroller_gain, -startup_history_state,\
					-size, -show_viewer_command, -hide_viewer_command\
					or -add_image_command"
			}
		}
	}
}

proc ::viewer::ChangeState {self {type "hide"}} {	

	upvar #0 [namespace current]::$self state
	
	switch -- $type {
		hide {
			set ucmd $state(-hide_viewer_command)
		}
		show {
			set ucmd $state(-show_viewer_command)
		}
	}
	
	if {[string length $ucmd] > 0} {
		set func [lindex $ucmd 0]
		set cargs [lrange $ucmd 1 end]
		set code [catch { eval $func $cargs } state]
		
		if {$code == 1} {
		::bgerror [format "Procedure %s returned code\
			%s\n%s" $func $code $state]
		return
		}
		
		if {$code == 3 || ($code == 0 && [string equal $state stop])} {
			return
		}
	}
	
	switch -- $type {
		hide {
			wm state $self withdraw
		}
		show {
			wm state $self normal
			focus -force $self
			if { ! $state(-startup_history_state)} {
			ToggleHistory $self 0
			} else {
			ToggleHistory $self 1
			}
		}
	}
	
	return
}

proc ::viewer::See {self index {by index}} {

	upvar #0 [namespace current]::$self state
	
	if {[string equal $by "index"]} {
	set inserttext [$state(listbox) get $index]
	} elseif {[string equal $by "text"]} {
	set inserttext $index
	}
	
	HistoryRedraw $self $inserttext
}

proc ::viewer::HistoryRedraw {self inserttext} {
	
	upvar #0 [namespace current]::$self state

	$state(listbox) delete 0 end
	
    SetHeader $self ""
    
	set groups [lsort [array names state groups,*]]
	
	# Without history style.
	if {[llength $groups] == 0 && [string length $state(last)] != 0 && [info exist state(image,$inserttext)]} {
		SetImage $self $state(image,$inserttext)
		SetHeader $self $inserttext
		return
	}
	
	foreach group $groups {
		lassign [split $group ,] - nameofgroup
		$state(listbox) insert end $nameofgroup
		$state(listbox) itemconfigure end -background black -foreground white
		$state(listbox) itemconfigure end -selectforeground white -selectbackground black
		if {[lsearch -exact $state(hidden) $nameofgroup] >= 0} \
		{$state(listbox) itemconfigure end -foreground gray ; continue}
		foreach child [lsort $state($group)] {
			$state(listbox) insert end $child
			$state(listbox) itemconfigure end -background white -foreground black
			$state(listbox) itemconfigure end -selectforeground black -selectbackground white
			if {[string equal $state(last) $child]} {$state(listbox) itemconfigure end -foreground green}
			if {[string equal $child $inserttext]} {
				$state(listbox) itemconfigure end -foreground red -selectforeground red
				SetImage $self $state(image,$inserttext)
				SetHeader $self "$nameofgroup - $inserttext"
				set state(current,inserttext) $inserttext
			}
		}
	}
}

proc ::viewer::ToggleHistory {self {force_type -1}} {

	upvar #0 [namespace current]::$self state
	
	switch -exact -- $force_type {
		1 {
			if {$state(historystate) == 0} { 
				$self.panel add $self.panel.history -before $self.panel.view
				set state(historystate) 1
			}
			return
		}
		0 {
			if {$state(historystate) == 1} { 
				$self.panel forget $self.panel.history
				set state(historystate) 0
			}
			return
		}	
	}
	
	if {$state(historystate) == 1} { 
	$self.panel forget $self.panel.history
	set state(historystate) 0
	} else {
	$self.panel add $self.panel.history -before $self.panel.view
	set state(historystate) 1
	}
}

proc ::viewer::ToggleGroup {self index} {

	upvar #0 [namespace current]::$self state
	
	set groupname [$state(listbox) get $index]
	
	if {![info exist state(groups,$groupname)]} {
	return
	}
	
	if {[set idx [lsearch -exact $state(hidden) $groupname]] >= 0} {
	set state(hidden) [lreplace $state(hidden) $idx $idx]
	} else {
	lappend state(hidden) $groupname
	}
	
	HistoryRedraw $self $groupname
}

proc ::viewer::ToggleAllGroups {self type} {

	upvar #0 [namespace current]::$self state
	
    if {![info exist state(current,inserttext)]} {
    return
    }
    
	set inserttext $state(current,inserttext)
	
	switch -- $type {
		hide {
			set state(hidden) {}
			foreach group [array names state groups,*] {
				lassign [split $group ,] - nameofgroup
				if {[lsearch -exact $state($group) $inserttext] < 0} { 
				lappend state(hidden) $nameofgroup
				}
			}
			HistoryRedraw $self ""
		}
		show {
			set state(hidden) {}
			HistoryRedraw $self $inserttext
		}
	}
}

proc ::viewer::PlaceWindow {self pos} {
	if {![string equal $pos "center"]} {
		wm geometry $self $pos
		return
	}
	
	update idletasks
	
	set w [winfo reqwidth  $self]
	set h [winfo reqheight $self]
	
	set x [expr {([winfo screenwidth  $self] - $w)/2 - [winfo vrootx $self]}]
	set y [expr {([winfo screenheight $self] - $h)/2 - [winfo vrooty $self]}]
	
	 wm geometry $self +${x}+${y}
}

proc ::viewer::SetSize {self size} {
	if { ! [string equal -nocase $size "default"]} {
		wm geometry $self $size 
	}
	
	update idletasks
}

proc ::viewer::ChangeScreenSize {self} {
	if { ! [string equal [wm state $self] "zoomed"]} {
		catch { wm state $self zoomed }
	} else {
		wm state $self normal
	}
}

proc ::viewer::CatchAttribute {attr self val} {
	if {$val < 0} {
		return
	}
	catch {
		if {[lsearch -exact [wm attributes $self] $attr] >= 0} {
			wm attributes $self $attr $val
		}
	}
}

proc ::viewer::Quit {self {force 0}} {
	upvar #0 [namespace current]::$self state
	
	if {$force} {return [destroy $self]}
	
	ChangeState $self hide
}

proc ::viewer::CanvasMenu {self} {
	upvar #0 [namespace current]::$self state
	
    set m .popup_viewer
	
    if { [winfo exists $m] } {
	destroy $m
    }

    menu $m -tearoff 0
	
	$m add command -label [::msgcat::mc "Copy URL to clipboard"] \
		-command [list [namespace origin CopyUrl] $self]
	$m add command -label [::msgcat::mc "Save image"] \
		-command [list [namespace origin SaveImage] $self]
	$m add command -label [::msgcat::mc "Close viewer"] \
		-command [list [namespace origin ChangeState] $self hide]
	$m add command -label [::msgcat::mc "Expand screen"] \
		-command [list [namespace origin ChangeScreenSize] $self]
	$m add command -label [::msgcat::mc "Toggle history state"] \
		-command [list [namespace origin ToggleHistory] $self]
	
	$m add cascade -label  [::msgcat::mc "Zoom"] \
		-menu [menu $m.zoom -tearoff 0]	
	$m.zoom add command -label [::msgcat::mc "Zoom in"] \
		-command [list [namespace origin ImageScale] $self 2]
	$m.zoom add command -label [::msgcat::mc "Zoom normal"] \
		-command [list [namespace origin ImageScale] $self normal]
	$m.zoom add command -label [::msgcat::mc "Zoom out"] \
		-command [list [namespace origin ImageScale] $self 0.5]
			
    tk_popup $m [winfo pointerx .] [winfo pointery .]
}

proc ::viewer::SaveImage {self} {

	upvar #0 [namespace current]::$self state
	
    if {![info exist state(current,inserttext)]} {
    return
    }
    
	set inserttext $state(current,inserttext)
	
	if {[string length $state(data,$inserttext)] == 0} {
	return
	}
	
	set filename [tk_getSaveFile -initialfile [file tail $inserttext] \
		-filetypes [list [list [string toupper [file extension $inserttext]] \
		[file extension $inserttext]]]]
	
	if {[string length $filename] == 0} { 
	return 
	}
   
	set fileid [open $filename "WRONLY CREAT"]
	fconfigure $fileid -translation binary
	puts $fileid [base64::decode $state(data,$inserttext)]
	close $fileid
}

proc ::viewer::CopyUrl {self} {

	upvar #0 [namespace current]::$self state
	
	clipboard clear -displayof $self
	clipboard append -displayof $self $state(last)
}

proc viewer::free_all {self} {
    upvar #0 [namespace current]::$self state
    if {![info exist state(current,inserttext)]} {
    return
    }
    set groups [lsort [array names state groups,*]]
    foreach group $groups {
        lassign [split $group ,] - url
        set m 0
        foreach child [lsort $state($group)] {
            incr m
            free $self $child
        }
        if {$m == 0} {
        unset state($group)
        }
    }
    
    unset state(current,inserttext)
    HistoryRedraw $self {}
}

proc viewer::free {self url} {
    variable viewer_screen
    
    upvar #0 [namespace current]::$self state
    
    catch { image delete vimage/$url }
    
    array unset state *,$url
    array unset state *,vimage/$url
    
    foreach v [array names state groups,*] {
        if {[lsearch -exact $state($v) $url] >= 0} {
        set idx [lsearch -exact $state($v) $url]
        set state($v) [lreplace $state($v) $idx $idx]
        }
    }
    
    variable scales
    if {[info exist scales]} {
        foreach img $scales {
            catch {image delete $img}
        }
        unset scales
    }
    
   foreach chatid [::chat::opened] {
    ::plugins::vimage::update_icon_on_chatwin $url $chatid image
    }
    
    if {[info exist ImagesData(image_resized,$url)]} {
    catch {image delete $ImagesData(image_resized,$url)}
    } 

    array unset ::plugins::vimage::ImagesData *,$url
}

proc ::viewer::ImageScale {self xfactor {yfactor 0}} {
	variable scales
    
    upvar #0 [namespace current]::$self state
	if {![info exist state(current,inserttext)]} {
    return
    }
    
	set inserttext $state(current,inserttext)
	
	if {[string equal $xfactor "normal"]} {
		SetImage $self $state(image,$inserttext)
		return
	}
	
	set example $state(image,$inserttext)
	
	if {[info exist state(scales,$inserttext,$xfactor,$yfactor)]} {
	SetImage $self $state(scales,$inserttext,$xfactor,$yfactor)
	return
	}
	
	set mode -subsample
	if { abs($xfactor) < 1 } {
		set xfactor [expr { round(1./$xfactor) }]
	} elseif { $xfactor >= 0 && $yfactor >= 0 } {
		set mode -zoom
	}
	
	if { $yfactor == 0 } {
		set yfactor $xfactor
	}
	
	set dest [image create photo]
	lappend scales $dest
    
    $dest copy $example -shrink $mode $xfactor $yfactor
	
	set state(scales,$inserttext,$xfactor,$yfactor) $dest
	SetImage $self $dest
}

proc ::viewer::uwp_data_set { widget key value } {
	variable uwp_data
	set uwp_data($widget:$key) $value
}

proc ::viewer::uwp_data_get { widget key } {
	variable uwp_data
	return $uwp_data($widget:$key)
}

proc ::viewer::uwp_p_append_tag { tag widget } {
	bindtags $widget [linsert [bindtags $widget] end $tag]
}

proc ::viewer::uwp_p_remove_tag { tag widget } {
	set idx [lsearch [set ell [bindtags $widget]] $tag]
	bindtags $widget [lreplace $ell $idx $idx]
}

proc ::viewer::alias { alias args } {
	eval { interp alias {} $alias {} } $args
}

proc ::viewer::uwp_grab_scroller_event_press { widget x y } {
	uwp_p_grab_scroller_bind_motion $widget
	uwp_p_grab_scroller_set_grab_cursor $widget
	$widget scan mark $x $y
}

proc ::viewer::uwp_grab_scroller_event_release { widget } {
	uwp_p_grab_scroller_unbind_motion $widget
	uwp_p_grab_scroller_set_ungrab_cursor $widget
}

proc ::viewer::uwp_grab_scroller_event_enter { widget } {
	uwp_p_grab_scroller_save_current_cursor $widget
	uwp_p_grab_scroller_set_ungrab_cursor $widget
}

proc ::viewer::uwp_grab_scroller_event_leave { widget } {
	uwp_p_grab_scroller_restore_current_cursor $widget
}

proc ::viewer::uwp_grab_scroller_event_motion { widget x y } {
	set self [winfo toplevel $widget]
	upvar #0 [namespace current]::$self state
	
	switch -exact -- $state(-scroller_gain) {
		sticky_mouse	{ set gain 1 }
		quick_scroll	{ set gain [expr {[winfo width $widget]/8}] }
	}
	
	$widget scan dragto $x $y $gain
}

proc ::viewer::uwp_p_grab_scroller_save_current_cursor { widget } {
	set self [winfo toplevel $widget]
	uwp_data_set $widget oldCursor [interp invokehidden {} $self cget -cursor]
}

proc ::viewer::uwp_p_grab_scroller_restore_current_cursor { widget } {
	set self [winfo toplevel $widget]
	interp invokehidden {} $self configure -cursor [uwp_data_get $widget oldCursor]
}

proc ::viewer::uwp_p_grab_scroller_set_grab_cursor { widget } {
	set self [winfo toplevel $widget]
	interp invokehidden {} $self configure -cursor [option get $widget uwp_grab_scroller_grab_cursor {}]
}
proc ::viewer::uwp_p_grab_scroller_set_ungrab_cursor { widget } {
	set self [winfo toplevel $widget]
	interp invokehidden {} $self configure -cursor [option get $widget uwp_grab_scroller_ungrab_cursor {}]
}

::viewer::alias uwp_grab_scroller_bind ::viewer::uwp_p_append_tag GrabScroller
::viewer::alias uwp_grab_scroller_unbind ::viewer::uwp_p_remove_tag GrabScroller
::viewer::alias uwp_p_grab_scroller_bind_motion	::viewer::uwp_p_append_tag GrabScrollerScroll
::viewer::alias uwp_p_grab_scroller_unbind_motion	::viewer::uwp_p_remove_tag GrabScrollerScroll
