# $Id: vimage.tcl 528 2012-12-24 18:05:56Z ancestor $
#
# Written by Renji <webrenji@gmail.com>
# See ~/doc/README for details.
#

namespace eval vimage {
global auto_path
global configdir
variable Config
variable System	
variable toolbar_button
variable useTkImageTools

	set System(script_dir) [file dirname [info script]]
	
	set auto_path [linsert $auto_path 0 [file join $System(script_dir) lib]]
	
	package require http
	package require msgcat
	package require viewer
	package require BWidget
	package require Img
	package require base64
	
	::msgcat::mcload [file join $System(script_dir) msgs]
	
	set System(extensions) {gif|pixmap}
	append System(extensions) {|bmp|ico|jpeg|jpg|pcx|}
	append System(extensions) {png|ppm|postscript|sgi|sun|}
	append System(extensions) {tga|tiff|xbm|xpm}
	
	# Hidden Group
	custom::defvar toolbar_button(index) {-1} \
	[::msgcat::mc "Last button index"] \
	-type string -group Hidden
	custom::defvar toolbar_button(state) {1} \
	[::msgcat::mc "Button (and plugin) state"] \
	-type string -group Hidden

	custom::defgroup Plugins [::msgcat::mc "Plugins options."] -group Tkabber	
    custom::defgroup Vimage [::msgcat::mc "Image Preview custom options."] -group Plugins
	
	custom::defvar Config(ignore_history_urls) 1 \
	[::msgcat::mc "Ignore the messages received from the history."] \
	-group Vimage -type boolean
	
	custom::defvar Config(validate_urls) 0 \
	[::msgcat::mc " Check the headers references (required if\
	the link redirects to another address)."] \
	-group Vimage -type boolean
	
	custom::defvar Config(auto_show_viewer) 1 \
	[::msgcat::mc "Automatically display the image\
	viewer window when a new image. Re-view of\
	one link is ignored."] \
	-group Vimage -type boolean
	
	custom::defvar Config(show_progressbar) 1 \
	[::msgcat::mc "Show download status indicator\
	of image."] \
	-group Vimage -type boolean
	
	custom::defvar Config(max_size) 100 \
	[::msgcat::mc "The maximum allowable size of the image,\
	which can be downloaded."] \
	-group Vimage -type integer
	
	custom::defvar Config(add_toolbar_button) 1 \
	[::msgcat::mc "Show icon in the dialog preview\
	the image on the system tray."] \
	-group Vimage -type boolean \
	-command [namespace current]::add_or_delete_button
	
	custom::defvar Config(show_tooltip) 1 \
	[::msgcat::mc "Show a small window to the thumbnail\
	when you hover on the icon of the state."] \
	-group Vimage -type boolean
	
	custom::defvar Config(image_width) 200 \
	[::msgcat::mc "Width of thumbnail images\
	(height chosen proportionally)."] \
	-group Vimage -type integer
	
	custom::defvar Config(image_scaling_size) 30 \
	[::msgcat::mc "The final size of a thumbnail."] \
	-group Vimage -type integer
	
	custom::defvar Config(auto_getting) 0 \
	[::msgcat::mc "Automatically download images\
	when getting links."] \
	-group Vimage -type boolean
	
	custom::defvar Config(resize_type) ScaleImage \
	[::msgcat::mc "Type of mechanism to reduce the image\
	(recommended TkImageTools, but if there is no problem with it)."] \
	-type options -group Vimage \
	-command [namespace current]::validate_resize_type \
	-values [list \
		TkImageTools [::msgcat::mc "Tk image tools extension"] \
		ScaleImage [::msgcat::mc "Pure Tcl image scale"] \
	]
	
	custom::defgroup Viewer [::msgcat::mc "Image viewer options."] -group Vimage
	
	custom::defvar Config(viewer,position) center \
	[::msgcat::mc "Window position (center - located in the\
	center, 100 100 - 100 pixels horizontally and vertically)."] \
	-group Viewer -type string \
	-command [namespace current]::viewer_configure
	
	custom::defvar Config(viewer,size) default \
	[::msgcat::mc "Window size image viewer (default -\
	standard, 500x500 - 500 by 500 pixels)."] \
	-group Viewer -type string \
	-command [namespace current]::viewer_configure
	
	custom::defvar Config(viewer,alpha) -1 \
	[::msgcat::mc "The depth of transparency (-1 - disabled, 100 - max)."] \
	-group Viewer -type string \
	-command [namespace current]::viewer_configure
	
	custom::defvar Config(viewer,topmost) 0 \
	[::msgcat::mc "Show the top."] \
	-group Viewer -type boolean \
	-command [namespace current]::viewer_configure
	
	custom::defvar Config(viewer,scroller_gain) sticky_mouse \
	[::msgcat::mc "Scroll speed images."] \
	-type options -group Viewer \
	-command [namespace current]::viewer_configure \
	-values [list \
		sticky_mouse [::msgcat::mc "Sticky mouse"] \
		quick_scroll [::msgcat::mc "Quick scroll"] \
	]
	
	custom::defvar Config(viewer,startup_history_state)  1 \
	[::msgcat::mc ""] \
	-command [namespace current]::viewer_configure \
	-type options -group Viewer -values [list \
		1 [::msgcat::mc "Auto show"] \
		0 [::msgcat::mc "Auto hide"] \
	]
	
	foreach file_data {toolbar.png normal.gif image.gif 
		process.gif error.gif large.gif 
		no_image_available.gif} {
			set name [lindex [split $file_data .] 0]
			image create photo vimage/$name \
				-file [file join $System(script_dir) pixmaps $file_data]
	}
}

proc vimage::validate_resize_type {args} {
variable Config 

	if { ! $::useTkImageTools && [string equal $Config(resize_type) "TkImageTools"]} {
		tk_messageBox -icon warning -title [::msgcat::mc "Load package: error"] \
			-message [::msgcat::mc "Can't find TkImageTools package."]
		set Config(resize_type) ScaleImage
	}
}

proc vimage::viewer_configure {args} {
variable Config
variable System

	foreach akey [array names Config viewer,*] {
		set option [lindex [split $akey ,] end]
		if {[info exist System(viewer)] && 
			[winfo exist $System(viewer)]} {
				$System(viewer) configure \
					-$option $Config($akey)
		}
	}
}

proc vimage::add_or_delete_button {args} {
variable Config

	switch -- $Config(add_toolbar_button) {
		1 add_toolbar_button 
		0 delete_toolbar_button
	}
}


proc vimage::add_toolbar_button {} {
variable toolbar_button
variable Config

	if { ! $Config(add_toolbar_button)} {
	return
	}
	
	catch {.mainframe gettoolbar 0} toolbar
	set bbox $toolbar.bbox
	
	if {[winfo exist $toolbar.bbox] && ![ButtonBox::exist $toolbar.bbox $toolbar_button(index)]} {
		set toolbar_button(index) [ifacetk::add_toolbar_button \
			vimage/toolbar \
				[list [namespace origin see_image_in_viewer] {}] \
					[::msgcat::mc "Show vimage history"]]
	}
}

proc vimage::delete_toolbar_button {} {
variable toolbar_button
	
	catch {.mainframe gettoolbar 0} toolbar
	set bbox $toolbar.bbox
	
	if {[winfo exist $toolbar.bbox] && [ButtonBox::exist $toolbar.bbox $toolbar_button(index)]} {
		ButtonBox::delete $toolbar.bbox $toolbar_button(index)
		set toolbar_button(index) -1
	}
}

proc vimage::add_or_delete_toolbar_button {args} {
variable Config 
	
	switch -- $Config(add_toolbar_button) {
		1 add_toolbar_button 
		0 delete_toolbar_button
	}
}

proc vimage::add_to_located {nurl lurl} {
variable ImagesData

	lappend ImagesData(located,$lurl) $nurl
	set  ImagesData(located,$lurl) \
		[lsort -unique $ImagesData(located,$lurl)]
}

proc vimage::draw_message {chatid from type body extras} {
variable Config
	
	foreach iUrl [get_image_urls $body] {
		set icon [lindex [split [get_state_icon $iUrl] /] end]
		update_icon_on_chatwin $iUrl $chatid $icon
		
		if {$Config(ignore_history_urls) && \
			[::xmpp::delay::exists $extras]} return
			
		if { ! [image_getted $iUrl] && $Config(auto_getting)} {
			schedule [namespace origin getting] $iUrl $chatid
		} else {
			show_process $iUrl $chatid
		}
	}
}

proc vimage::comp_getting {iUrl chatid} {
variable Config

	set old_msize $Config(max_size)
	set Config(max_size) 1000000
	
	getting $iUrl $chatid -reload
	
	set Config(max_size) $old_msize
}

proc vimage::getting {iUrl chatid {type -get}} {

	if {[string equal $type "-reload"]} \
		{set_state_getting $iUrl reload}
	
	update_icon_on_chatwin $iUrl $chatid process
		
	if { ! [image_getted $iUrl]} {
	get_image_from_url $iUrl $chatid
	}
	
	show_process $iUrl $chatid
	clean_process_update $iUrl $chatid
}

proc vimage::show_process {iUrl chatid} {

	switch -exact -- [image_state $iUrl] {
		-1 {
			update_icon_on_chatwin $iUrl $chatid image
		}
		0 {
			update_icon_on_chatwin $iUrl $chatid normal
			show_process_normal $iUrl $chatid
		}
		1 {
			update_icon_on_chatwin $iUrl $chatid large
		}
		2 {
			update_icon_on_chatwin $iUrl $chatid error
		}
	}
}

proc vimage::show_process_normal {iUrl chatid} {
variable Config

	add_image_in_viewer \
			[image_id $iUrl] [::chat::get_jid $chatid] $iUrl
			
	if {$Config(auto_show_viewer) && ![image_showed $iUrl]} {
	after idle [list [namespace origin see_image_in_viewer] $iUrl]
	}
	
	if {$Config(show_tooltip)} {
		addResized $iUrl
	}
}

proc vimage::get_image_from_url {iUrl chatid} {
variable Config
	
	if {$Config(validate_urls)} {
	set iUrl [location $iUrl]
	}
	
	if {[catch {set token [http::geturl $iUrl -binary 1 -blocksize 1024 \
		-command [list [namespace origin image_get_end] $iUrl $chatid] \
		-progress [list [namespace origin image_get_process] $iUrl $chatid]] 
	}]} {return [set_state_getting $iUrl error]}
	
	http::wait $token
}

proc vimage::location {iUrl} {
	if {[catch {set token [http::geturl $iUrl -validate 1]} err]} \
		{return $iUrl}
	
	foreach {type value} [http::meta $token] {
		if {[string equal $type "Location"]} \
			{set iUrl $value}
	}
	
	return $iUrl
}

proc vimage::image_get_end {iUrl chatid token} {
	imageDataSet $iUrl [::base64::encode [http::data $token]]
	if {[catch {image create photo vimage/$iUrl -data [imageDataGet $iUrl]}]} {
	set_state_getting $iUrl error
	} else {set_state_getting $iUrl normal vimage/$iUrl}

	
	http::cleanup $token
}

proc vimage::imageDataSet {iUrl data} {
variable ImagesData

	set ImagesData(data,$iUrl) $data
}

proc vimage::imageDataGet {iUrl} {
variable ImagesData
	
	if {[info exist ImagesData(data,$iUrl)]} {
	return $ImagesData(data,$iUrl)
	}
}

proc vimage::image_get_process {iUrl chatid token total current} {
variable Config
	
	setImageSize $iUrl $total
	
	CurrentTokenSet $token
	
	set max_size [expr {$Config(max_size)*1024}]
	if {$current > $max_size || $total > $max_size} {
	stop_getting $iUrl $chatid large
	}
	
	update_url_getting_on_chatwin $iUrl $chatid $total $current
	
	return
}

proc vimage::stop_getting {iUrl chatid {type error}} {
variable Config
	
	catch {::http::reset [CurrentTokenGet]}
	
	set_state_getting $iUrl $type
	update_icon_on_chatwin $iUrl $chatid $type
}


proc vimage::CurrentTokenSet {token} {
variable ImagesData

	set ImagesData(token) $token
}

proc vimage::CurrentTokenGet {} {
variable ImagesData

	if {[info exist ImagesData(token)]} {
		return $ImagesData(token)
	}
}

proc vimage::setImageSize {iUrl total} {
variable ImagesData

	set ImagesData(total,$iUrl) $total
}

proc vimage::getImageSize {iUrl} {
variable ImagesData

	if {[info exist ImagesData(total,$iUrl)]} {
		return $ImagesData(total,$iUrl)
	}
	
	return 0
}

proc vimage::clean_process_update {iUrl chatid} {
	catch {destroy .mainframe.status.prgf.prb}
	catch {destroy .mainframe.status.prgf.from}
	catch {destroy .mainframe.status.prgf.mon}
}

proc vimage::update_url_getting_on_chatwin {iUrl chatid total current} {
variable Config

	set current [expr {round($current / 1024)}]
	set total [expr {round($total / 1024)}]

	set [namespace current]::progress-$iUrl $current
	progressbar [namespace current]::progress-$iUrl $total $current [::chat::get_jid $chatid]

	return
}

proc vimage::update_icon_on_chatwin {iUrl chatid type} {
variable Config
	
	set chatwin [::chat::chat_win $chatid]
	set tag icon/$iUrl
	
	foreach {sind eind} [$chatwin tag range [list uri $iUrl]] {
		if {[lsearch [$chatwin tag names $eind] $tag] < 0} {
			$chatwin image create $eind -image vimage/$type -padx 2
			$chatwin tag add $tag $eind
		}
		$chatwin image configure $eind -image vimage/$type
		bind_set $chatid $tag $iUrl $type
	}
	
	update idletasks
}

proc vimage::bind_set {chatid tag iUrl type} {
variable Config 
	
	set chatwin [::chat::chat_win $chatid]
	
	if {$Config(show_tooltip)} {
	$chatwin tag bind $tag <Any-Enter> [list [namespace origin showTooltip] %W $tag $iUrl]
	$chatwin tag bind $tag <Any-Motion> [list [namespace origin motionTooltip] %W]
	$chatwin tag bind $tag <Any-Leave> [list destroy %W.tooltip]
	$chatwin tag bind $tag <Any-KeyPress> [list destroy %W.tooltip]
	$chatwin tag bind $tag <Any-Button> [list destroy %W.tooltip]
	}
	
	# Change a cursor
	$chatwin tag bind $tag  <Any-Enter> +[list [namespace origin on_icon] Any-Enter $iUrl [double% $chatid]]
	$chatwin tag bind $tag <Any-Leave> +[list [namespace origin on_icon] Any-Leave $iUrl [double% $chatid]]
	
	# View image
	$chatwin tag bind $tag <Button-1><ButtonRelease-1> [list [namespace origin on_icon] 1 [double% $iUrl] [double% $chatid] $type]
}

proc vimage::on_icon {button iUrl chatid {type ""}} {
	set chatwin [::chat::chat_win $chatid]
	
	switch -exact -- $button {
		1 {
			switch -exact -- $type {
				normal {
					see_image_in_viewer $iUrl
				}
				large {
					comp_getting $iUrl $chatid
				}
				process {
					stop_getting $iUrl $chatid
				}
				image -
				error {
					getting $iUrl $chatid -reload
				}
			}
		}
		2 {
			getting $iUrl $chatid -reload
		}
		Any-Enter {
			$chatwin configure -cursor hand2
		}
		Any-Leave {
			$chatwin configure -cursor xterm
		}
	}
}

proc vimage::progressbar { varname max current jid } {
variable Config

	set win .mainframe.status.prgf
	
	if { ! $Config(show_progressbar)} {
	return
	}
	
	set crm "($current)"
	set fg red
	if {$max > 0} {
		set crm "($current/$max)"
		if {$current >= [expr {$max / 2}]} {
			set fg green
		} 
	}
	
	set type nonincremental_infinite
	if {$max > 0} {
	set type normal
	}
	
	if {[winfo exist $win] && [winfo exist $win.prb]} { 
		if {$max > 0} {
			$win.prb configure -maximum $max -variable $varname -type $type
			$win.from configure -text $jid			
			$win.mon configure -foreground $fg -text $crm
		}
		return 
	}
	
	catch {
		label $win.from -text $jid -background [$win cget -background]
		
		ProgressBar $win.prb -type $type \
			-variable $varname -relief groove -maximum $max
		
		label $win.mon -text $crm \
			-background [$win cget -background] \
			-foreground $fg
		
		pack $win.from $win.prb $win.mon -padx 2 -side left
	}
}

proc vimage::see_image_in_viewer {iUrl} {
variable System
	
	add_to_showed $iUrl
	
	if {[info exist System(viewer)] && 
		[winfo exist $System(viewer)]} {
			$System(viewer) see $iUrl text
			$System(viewer) show
	}
}

proc vimage::add_image_in_viewer {image_id jid iUrl} {
variable System
variable Config

	if { ! [info exist System(viewer)] || ! [winfo exist $System(viewer)]} {
		set System(viewer) .viewer_screen
		::viewer::viewer .viewer_screen -position $Config(viewer,position) \
			-alpha $Config(viewer,alpha) -topmost $Config(viewer,topmost) \
			-size $Config(viewer,size) -scroller_gain $Config(viewer,scroller_gain) \
			-startup_history_state $Config(viewer,startup_history_state)
	}
	
	$System(viewer) add $jid $iUrl $image_id [imageDataGet $iUrl]
}

proc vimage::set_state_getting {iUrl type {image_id ""}} {
	variable ImagesData
	
	switch -exact -- $type {
		error {
			set ImagesData(getted,$iUrl) 0
			set ImagesData(state,$iUrl) 2
			set ImagesData(image,$iUrl) {}
			set ImagesData(image_resized,$iUrl) {}
		}
		normal {
			set ImagesData(getted,$iUrl) 1
			set ImagesData(state,$iUrl) 0
			set ImagesData(image,$iUrl) $image_id
			set ImagesData(image_resized,$iUrl) {}
		}
		large {
			set ImagesData(getted,$iUrl) 0
			set ImagesData(state,$iUrl) 1
			set ImagesData(image,$iUrl) {}
			set ImagesData(image_resized,$iUrl) {}
		}
		init {
			set ImagesData(getted,$iUrl) 0
			set ImagesData(state,$iUrl) -1
			set ImagesData(image,$iUrl) {}
			set ImagesData(image_resized,$iUrl) {}
		}
		reload {
			array unset ImagesData *,$iUrl
		}
	}
}
	
proc vimage::image_getted {iUrl} {
variable ImagesData

	expr {[info exist ImagesData(getted,$iUrl)] && 
			$ImagesData(getted,$iUrl)}
}

proc vimage::image_state {iUrl} {
variable ImagesData

	expr {[info exist ImagesData(state,$iUrl)] ? \
		$ImagesData(state,$iUrl) : -1}
}

proc vimage::image_id {iUrl} {
variable ImagesData
	expr {[info exist ImagesData(image,$iUrl)] ? \
		$ImagesData(image,$iUrl) : ""}
}

proc vimage::get_state_icon {iUrl} {
	
	switch -exact -- [image_state $iUrl] {
		-1 {
			return vimage/image
		}
		0 {
			return vimage/normal
		}
		1 {
			return vimage/large
		}
		2 {
			return vimage/error
		}
	}
	
	return vimage/error
}

proc vimage::addResized {iUrl {image_id ""}} {
variable ImagesData
variable Config
	
	if { ! $::useTkImageTools} {
	set Config(resize_type) ScaleImage
	}
	
	if {[string length $image_id] == 0} {
	set image_id [image_id $iUrl]
	}
	
	set iw [image width $image_id]
	set ih [image height $image_id]
	set mw $Config(image_width)
	set mh [expr {round( $ih / ( $iw / $mw + 1))}]
	
	if {$iw <= $mw || $ih <= $mh} {
	return [set ImagesData(image_resized,$iUrl) $image_id]
	}
	
	switch -exact $Config(resize_type) {
		TkImageTools {
			set ImagesData(image_resized,$iUrl) [resize $image_id $mw $mh]
		}
		ScaleImage {
			set ImagesData(image_resized,$iUrl) [imageScale $image_id $Config(image_scaling_size)]
		}
	}
	
	return
}

proc vimage::imageScale {image percent} {

	set deno [gcd $percent 100]
	set zoom [expr {$percent/$deno}]
	set subsample [expr {100/$deno}]
	
	set im1 [image create photo]
	$im1 copy $image -zoom $zoom
	
	set im2 [image create photo]
	$im2 copy $im1 -subsample $subsample
	
	image delete $im1
	
	return $im2
}

proc vimage::gcd {u v} {
	expr {$u? [gcd [expr $v%$u] $u]: $v}
}

proc vimage::resize {image_id mw mh} {

	set dest [image create photo]
	tkImageTools::resize $image_id $dest $mw $mh
	
	return $dest
}

proc vimage::getResized {iUrl} {
variable ImagesData

	if {[info exist ImagesData(image_resized,$iUrl)] && 
		[string length $ImagesData(image_resized,$iUrl)] > 0} {
			return $ImagesData(image_resized,$iUrl)
	}
	
	return [addResized {} vimage/no_image_available]
}

proc vimage::get_image_urls {str} {
variable System
	
	set regUrls {(https?://[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,4}(?:\/\S*)?(?:[a-zA-Z0-9_])+\.(?:@INSERT@))}
	regsub -all @INSERT@ $regUrls $System(extensions) regularString
	lsort -unique [regexp -inline -nocase -all -- "$regularString" $str]
}

proc vimage::get_all_urls {str} {
	set regUrls {(https?://[a-z0-9\-]+\.[a-z0-9\-\.]+(?:/|(?:/[a-zA-Z0-9!#\$%&'\*\+,\-\.:;=\?@\[\]_~]+)*))}
	lsort -unique [regexp -inline -nocase -all -- $regUrls $str]
}

proc vimage::image_showed {iUrl} {
variable ImagesData

	if {[info exist ImagesData(showed,$iUrl)]} {
		return $ImagesData(showed,$iUrl)
	}
	
	return 0
}

proc vimage::add_to_showed {iUrl} {
variable ImagesData
	set ImagesData(showed,$iUrl) 1
}

proc vimage::schedule {args} {
    after idle [list after 0 $args]
}

proc vimage::init_menu {m chatwin X Y x y} {
	set tags [$chatwin tag names "@$x,$y"]	
    set idx [lsearch $tags href_*]
	set idx1 [lsearch $tags uri*]
	
	 if { $idx < 0 } {
		return
	}
	
    if { $idx1 >= 0 } {
		set iUrl [lindex [lindex $tags $idx1] 1]
    } else {
		lassign [$w tag prevrange url "@$x,$y"] a b
		set iUrl [$w get $a $b]
    }
	
	set winid [chatwin_to_winid $chatwin]
	set chatid [::chat::winid_to_chatid $winid]
	create_menu $iUrl $m $chatid
}

proc vimage::create_menu {iUrl m chatid} {
	
	$m add cascade -label  [::msgcat::mc "Vimage"] \
		-menu [menu $m.vimage -tearoff 0]	
		
	$m.vimage add command \
		-label [::msgcat::mc "Get"] \
		-command [list [namespace origin getting] $iUrl $chatid] \
		-state [expr {[image_getted $iUrl] ? "disabled" : "normal"}]
		
	$m.vimage add command \
		-label [::msgcat::mc "View"] \
		-command [list [namespace origin see_image_in_viewer] $iUrl] \
		-state [expr {[image_getted $iUrl] ? "normal" : "disabled"}]
	
	$m.vimage add command \
		-label [::msgcat::mc "Reload"] \
		-command [list [namespace origin getting] $iUrl $chatid -reload] \
		-state [expr {[image_state $iUrl] >= 0 ? "normal" : "disabled"}]
		
	$m.vimage add command \
		-label [::msgcat::mc "Comp get"] \
		-command [list [namespace origin comp_getting] $iUrl $chatid] \
		-state [expr {[image_state $iUrl] == 1 ? "normal" : "disabled"}]	
		
	$m add separator
}

proc vimage::chatwin_to_winid {w} {
	set last $w
	if {[winfo parent $w] == "."} {return $last}
	return [chatwin_to_winid [winfo parent $w]]
}
 
proc vimage::showTooltip {widget tag iUrl} {
	if {[string match $widget* [winfo containing  \
		[winfo pointerx .] [winfo pointery .]]] == 0 } {
			return
	}

	if {[winfo exist $widget.tooltip]} {
	destroy $widget.tooltip
	}

	set img_id [getResized $iUrl]
	
	set scrh [winfo screenheight $widget] 
	set scrw [winfo screenwidth $widget]
	set tooltip [toplevel $widget.tooltip]

	wm geometry $tooltip +$scrh+$scrw 

	catch {wm overrideredirect $tooltip 1}

	if {[lsearch -exact [wm attributes $tooltip] "-topmost"] >= 0} {
	wm attributes $tooltip -topmost 1
	}

	pack [label $tooltip.label -image $img_id -justify left]

	update idletasks

	set width [winfo reqwidth $tooltip.label]
	set height [winfo reqheight $tooltip.label]

	set x [winfo pointerx .]
	set y [winfo pointery .]

	set pbm [expr {$y > ([winfo screenheight .] / 2.0)}]

	set positionX [expr {$x + 10}]
	set positionY [expr {$y+ round($height / 2.0) * ($pbm * -2 + 1) - round($height / 2.0)}]

	if  {$positionX > [expr {round([winfo screenwidth .] / 2)}]} {
	set positionX [expr {$positionX - $width - 20}]
	}

	wm geometry $tooltip +[join  "$positionX + $positionY" {}]

	raise $tooltip

	bind $widget.tooltip <Any-Enter> "destroy %W"
	bind $widget.tooltip <Any-Leave> "destroy %W"
}

proc vimage::motionTooltip {widget} {
	if { ! [winfo exist $widget.tooltip]} {
	return
	}
	
	if {[string match $widget* [winfo containing  \
		[winfo pointerx .] [winfo pointery .]]] == 0 } {
			return
	}
	
	set width [winfo reqwidth $widget.tooltip.label]
	set height [winfo reqheight $widget.tooltip.label]

	set x [winfo pointerx .]
	set y [winfo pointery .]

	set pbm [expr {$y > ([winfo screenheight .] / 2.0)}]

	set positionX [expr {$x + 10}]
	set positionY [expr {$y+ round($height / 2.0) * ($pbm * -2 + 1) - round($height / 2.0)}]

	if  {$positionX > [expr {round([winfo screenwidth .] / 2)}]} {
	set positionX [expr {$positionX - $width - 20}]
	}

	wm geometry $widget.tooltip +[join  "$positionX + $positionY" {}]
}

proc ::ButtonBox::exist {path index} {
    variable $path
    upvar 0 $path data
	
	return [expr {[lsearch -exact $data(buttons) $index] >= 0}]	
}

proc ::ButtonBox::delete {path idx} {
    variable $path
    upvar 0  $path data

    set i [lsearch -exact $data(buttons) $idx]
    set data(buttons) [lreplace $data(buttons) $i $i]
    destroy $path.b$idx
}

namespace eval vimage {
	
	if {[catch {package require TkImageTools}]} {
		set ::useTkImageTools 0
	} else {set ::useTkImageTools 1}
	
	hook::add draw_message_post_hook [namespace origin draw_message] 80
	hook::add chat_win_popup_menu_hook [namespace origin init_menu] 1
	hook::add finload_hook [namespace origin add_or_delete_button] 80
}
