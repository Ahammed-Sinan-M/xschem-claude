# Diagnostic for "MMB press-drag does not pan" (issue 1376).
# Source this in a running xschem, then press the middle button on the
# schematic canvas, drag a few centimetres, and release.
#   source tests/headless/probe_mmb_pan.tcl
# Every event xschem's canvas actually receives is printed. Paste the output.
namespace eval mmbprobe {
    variable t0 0
    variable n 0
    proc say {kind b s x y} {
        variable t0 ; variable n
        set now [clock milliseconds]
        if {$t0 == 0} { set t0 $now }
        incr n
        set ui 0 ; catch {set ui [xschem get ui_state]}
        set pan [expr {($ui & 512) ? {STARTPAN} : {.}}]
        set gp  [expr {($ui & 32768) ? {GRAPHPAN} : {.}}]
        puts [format "%3d %6d ms  %-14s button=%-3s state=%-5s (%s)  xy=%s,%s  ui=%-6s %s %s" \
              $n [expr {$now - $t0}] $kind $b $s [mmbprobe::bits $s] $x $y $ui $pan $gp]
    }
    proc bits {s} {
        if {![string is integer -strict $s]} { return ? }
        set out {}
        foreach {m nm} {1 Shift 2 Lock 4 Ctrl 8 Mod1 16 Mod2/Num 32 Mod3 64 Mod4 128 Mod5
                        256 Btn1 512 Btn2 1024 Btn3 2048 Btn4 4096 Btn5} {
            if {$s & $m} { lappend out $nm }
        }
        return [expr {[llength $out] ? [join $out +] : {none}}]
    }
    proc arm {} {
        variable t0 ; variable n
        set t0 0 ; set n 0
        foreach w [list .drw] {
            if {![winfo exists $w]} continue
            bind $w <Button>        {+::mmbprobe::say ButtonPress   %b %s %x %y}
            bind $w <ButtonRelease> {+::mmbprobe::say ButtonRelease %b %s %x %y}
            bind $w <Motion>        {+::mmbprobe::say Motion        -  %s %x %y}
        }
        puts "mmbprobe: armed on .drw. Now MIDDLE-button press, drag, release."
        puts "mmbprobe: canvas [winfo width .drw]x[winfo height .drw], DISPLAY $::env(DISPLAY)"
        puts "mmbprobe: server [winfo server .]"
        puts "mmbprobe: graph rects on this sheet = [xschem get rects 2]"
    }
}
::mmbprobe::arm
