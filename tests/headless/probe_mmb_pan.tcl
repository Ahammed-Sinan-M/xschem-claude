# Diagnostic for "MMB press-drag does not pan" (issue 1376).
# Source this in a running xschem, then press the middle button on the
# schematic canvas, drag a few centimetres, and release.
#   source tests/headless/probe_mmb_pan.tcl
# Every event xschem's canvas actually receives is printed. Paste the output.
namespace eval mmbprobe {
    variable t0 0
    variable n 0
    ## ⚠ WHERE THIS WRITES, AND WHY NOT `puts` (the first version's defect).
    ## The CIW captures a command's stdout only WHILE that command runs
    ## (ciw_capture_puts, src/ciw.tcl:565). This proc fires from an EVENT
    ## BINDING long after `source` returned, so a `puts` here goes to the
    ## process's own stdout -- a terminal the user may not even have -- and the
    ## user sees an armed probe that then says nothing for the rest of the
    ## session. MEASURED: their /tmp/Xschem.log.3 holds the four arming lines
    ## and not one event line, and the conclusion drawn from that silence was
    ## wrong twice over.
    ##
    ## So every line goes to the ACTION LOG, through the same `#= ` door the
    ## arming lines took -- the file the user already shares -- and to the CIW
    ## when one exists. Both are caught: a probe that raises inside a <Motion>
    ## binding would fire a background error on every pointer move.
    proc emit {line} {
        catch {xschem log_action -noecho "#= $line"}
        if {[llength [info commands ciw_echo]]} { catch {ciw_echo $line} }
    }
    proc say {kind b s x y} {
        variable t0 ; variable n
        set now [clock milliseconds]
        if {$t0 == 0} { set t0 $now }
        incr n
        set ui 0 ; catch {set ui [xschem get ui_state]}
        set pan [expr {($ui & 512) ? {STARTPAN} : {.}}]
        set gp  [expr {($ui & 32768) ? {GRAPHPAN} : {.}}]
        ## Motion is throttled: a drag is hundreds of events and the log is the
        ## user's, not ours. Every press and release is kept.
        if {$kind eq {Motion}} {
            variable mot
            if {![info exists mot]} { set mot 0 }
            incr mot
            if {$mot % 15 != 1} { return }
        }
        mmbprobe::emit [format "%3d %6d ms  %-14s button=%-3s state=%-5s (%s)  xy=%s,%s  ui=%-6s %s %s" \
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
        ## ⚠ EVERY CANVAS, NOT `.drw` ALONE. A tabbed or multi-window session
        ## drives `.x1.drw`, `.x2.drw` ... and `xschem get current_win_path`
        ## says which one is current. Arming the one hardcoded path would make
        ## a probe that is armed, live, and blind to the window the user is
        ## actually clicking in -- indistinguishable, in the output, from a
        ## mouse that sends nothing.
        set canvases {}
        foreach t [concat . [winfo children .]] {
            foreach cand [list [expr {$t eq {.} ? {.drw} : "$t.drw"}]] {
                if {[winfo exists $cand]} { lappend canvases $cand }
            }
        }
        catch {
            set cur [xschem get current_win_path]
            if {$cur ne {} && [winfo exists $cur] && [lsearch -exact $canvases $cur] < 0} {
                lappend canvases $cur
            }
        }
        if {![llength $canvases]} { set canvases [list .drw] }
        foreach w $canvases {
            if {![winfo exists $w]} continue
            bind $w <Button>        {+::mmbprobe::say ButtonPress   %b %s %x %y}
            bind $w <ButtonRelease> {+::mmbprobe::say ButtonRelease %b %s %x %y}
            bind $w <Motion>        {+::mmbprobe::say Motion        -  %s %x %y}
        }
        mmbprobe::emit "mmbprobe: armed on [join $canvases { }]"
        mmbprobe::emit "mmbprobe: current canvas [catch {xschem get current_win_path} cw]$cw"
        mmbprobe::emit "mmbprobe: server [winfo server .], DISPLAY $::env(DISPLAY)"
        mmbprobe::emit "mmbprobe: graph rects on this sheet = [xschem get rects 2]"
        mmbprobe::emit "mmbprobe: LEFT-button click first (to prove the probe is live), then MIDDLE press-drag-release."
    }
}
::mmbprobe::arm
