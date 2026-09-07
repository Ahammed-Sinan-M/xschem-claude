#!/usr/bin/wish
# Standalone mouse / X-server check for issue 1376 -- NO xschem involved.
#   wish tests/headless/mouse_check.tcl
# Press and HOLD each mouse button in the grey box, drag, release.
# Everything is shown IN THE WINDOW, so no terminal is needed.
#
# WHY NO `format` APPEARS INSIDE A bind SCRIPT HERE. Tk substitutes its own
# %-sequences into a binding script BEFORE Tcl parses it, so a format string
# containing %s or %d inside a binding is rewritten with the event's state and
# then fails or lies. The first version of this file did exactly that and
# printed "button=-2s held=512 ms". Every binding below therefore does nothing
# but pass the raw substitutions to a proc, where % is ordinary text.
package require Tk
wm title . {Mouse check - press, drag, release each button}
wm geometry . 780x470
array set ::down {}
array set ::moved {}
set ::n 0

frame .top
label .top.l -anchor w -text {Press and HOLD a button in the grey box, drag it, then release.}
pack .top.l -side left -padx 6 -pady 4
button .top.c -text Clear -command {
    .t configure -state normal ; .t delete 1.0 end ; .t configure -state disabled ; set ::n 0
}
pack .top.c -side right -padx 6
pack .top -side top -fill x

frame .pad -background #cccccc -width 760 -height 140
pack .pad -side top -fill x -padx 8 -pady 4
pack propagate .pad 0
label .pad.hint -background #cccccc -text {  <-- press here} -anchor nw
place .pad.hint -x 8 -y 8

text .t -height 17 -width 104 -font TkFixedFont -state disabled -wrap none
pack .t -side top -fill both -expand 1 -padx 8 -pady 4

proc say {s} {
    .t configure -state normal
    .t insert end "$s\n"
    .t see end
    .t configure -state disabled
}

proc bits {s} {
    if {![string is integer -strict $s]} { return ? }
    set out {}
    foreach {m nm} {1 Shift 2 Lock 4 Ctrl 8 Mod1 16 Mod2/Num 32 Mod3 64 Mod4
                    128 Mod5 256 Btn1 512 Btn2 1024 Btn3 2048 Btn4 4096 Btn5} {
        if {$s & $m} { lappend out $nm }
    }
    return [expr {[llength $out] ? [join $out +] : {none}}]
}

proc on_press {b s x y} {
    incr ::n
    set ::down($b) [clock milliseconds]
    set ::moved($b) 0
    say [format {%3d  PRESS    button=%-2s  state=%-5s (%s)  at %s,%s} \
             $::n $b $s [bits $s] $x $y]
}

proc on_motion {s x y} {
    if {![array size ::down]} return
    foreach b [array names ::down] { incr ::moved($b) }
    set b [lindex [array names ::down] 0]
    if {$::moved($b) % 15 == 1} {
        say [format {     motion   state=%-5s (%s)  at %s,%s} $s [bits $s] $x $y]
    }
}

proc on_release {b s x y} {
    set held -1
    set mv -1
    if {[info exists ::down($b)]} {
        set held [expr {[clock milliseconds] - $::down($b)}]
        set mv $::moved($b)
        unset ::down($b)
        unset ::moved($b)
    }
    set verdict {}
    if {$held < 0} {
        set verdict {<-- RELEASE WITH NO PRESS: the server never sent the press}
    } elseif {$held < 60 && $mv == 0} {
        set verdict {<-- CLICK, NOT A HOLD: press and release arrived together}
    }
    say [format {     RELEASE  button=%-2s  held=%s ms  motion-while-down=%s  %s} \
             $b $held $mv $verdict]
    say {}
}

bind .pad <Button>        {on_press %b %s %x %y}
bind .pad <Motion>        {on_motion %s %x %y}
bind .pad <ButtonRelease> {on_release %b %s %x %y}

say "server : [winfo server .]"
say "display: $::env(DISPLAY)"
say "Tk     : [info patchlevel]"
say {----------------------------------------------------------------}
say {LEFT button first (to prove the box is live), then the MIDDLE button.}
say {Press and HOLD, drag a few centimetres, then release.}
say {}
