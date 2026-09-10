# PREVIEW ONLY — redefines ase::theme / apply_theme in memory. No file is edited.
set SHOT /tmp/claude-1000/-home-analog-dev-xschem-claude/1e23e38a-228a-491e-a9b0-387bda9d283e/scratchpad/uxshots
proc pause {ms} { set ::__d 0 ; after $ms {set ::__d 1} ; vwait ::__d }
proc shotw {name w} { global SHOT
  update idletasks ; pause 500 ; update idletasks
  if {![winfo exists $w]} { puts "SHOT $name MISSING $w" ; return }
  catch {wm deiconify $w} ; catch {raise $w} ; pause 450 ; update idletasks
  catch {exec import -window [winfo id $w] $SHOT/$name.png} e
  puts "SHOT $name geom=[wm geometry $w] '$e'" }

# ---- the proposed font system: derive, never name a family -------------------
proc ase::theme {{name {}}} {
  set base [font actual TkDefaultFont -size]
  if {$base <= 0} { set base 10 }
  set fam  [font actual TkDefaultFont -family]
  set mfam [font actual TkFixedFont   -family]
  foreach {n f sz wt} [list \
      AseEntryFont  $fam  $base            normal \
      AseLabelFont  $fam  $base            bold   \
      AseMonoFont   $mfam $base            normal \
      AseHintFont   $fam  [expr {$base-1}] normal] {
    if {[lsearch -exact [font names] $n] < 0} { font create $n }
    font configure $n -family $f -size $sz -weight $wt -slant roman \
                      -underline 0 -overstrike 0
  }
  option add *TCombobox*Listbox.font AseEntryFont
  catch {ttk::style configure Ase.TCombobox -fieldbackground [ase::palette table]}
  catch {
    ttk::style configure Ase.Treeview -font AseEntryFont \
      -background [ase::palette table] -fieldbackground [ase::palette table] \
      -foreground [ase::palette fieldfg] \
      -rowheight [expr {[font metrics AseEntryFont -linespace] + 6}]
    ttk::style map Ase.Treeview \
      -background [list disabled [ase::palette disabledbg] selected [ase::palette selectbg]] \
      -foreground [list disabled [ase::palette disabledfg] selected [ase::palette selectfg]]
    ttk::style configure Ase.Treeview.Heading -font AseLabelFont \
      -background [ase::palette header] -foreground [ase::palette fieldfg]
  }
  return [ase::palette $name]
}

# ---- apply_theme: set FOREGROUND too, and stop bolding ordinary text ---------
proc ase::ui::apply_theme {w} {
  set cls [winfo class $w]
  switch -- $cls {
    Toplevel - Frame {
      catch {$w configure -background [ase::theme panel]}
    }
    Labelframe {
      catch {$w configure -background [ase::theme panel] \
                          -foreground [ase::theme accent] -font AseLabelFont}
    }
    Menu {
      catch {$w configure -background [ase::theme panel] \
                          -foreground [ase::theme fieldfg] \
                          -activeforeground [ase::theme fieldfg] \
                          -activebackground [ase::theme header] \
                          -disabledforeground [ase::theme disabledfg] \
                          -font AseEntryFont}
    }
    Button - Checkbutton - Radiobutton {
      catch {$w configure -background [ase::theme panel] \
                          -foreground [ase::theme fieldfg] \
                          -activeforeground [ase::theme fieldfg] \
                          -activebackground [ase::theme header] \
                          -disabledforeground [ase::theme disabledfg] \
                          -font AseEntryFont}
    }
    Label {
      catch {$w configure -background [ase::theme panel] \
                          -foreground [ase::theme fieldfg] -font AseEntryFont}
    }
    Entry {
      catch {$w configure -background [ase::theme table] \
                          -foreground [ase::theme fieldfg] \
                          -disabledforeground [ase::theme disabledfg] \
                          -font AseEntryFont}
    }
    Text {
      catch {$w configure -background [ase::theme table] \
                          -foreground [ase::theme fieldfg] -font AseMonoFont}
    }
    TCombobox { catch {$w configure -font AseEntryFont -style Ase.TCombobox} }
    Treeview  { catch {$w configure -style Ase.Treeview} }
    Scrollbar { catch {$w configure -background [ase::theme panel]} }
  }
  foreach c [winfo children $w] { ase::ui::apply_theme $c }
}

ase::open_state sky130_tests_ase tb_bandgap ngspice_state1
pause 1200
set key [ase::session_key sky130_tests_ase tb_bandgap ngspice_state1]
set W [ase::ui::window_for $key]

# ---- column widths measured from the font, not written down in pixels -------
proc fitcols {tv specs} {
  foreach {c txt} $specs {
    set px [expr {[font measure AseEntryFont $txt] + 18}]
    catch {$tv column $c -width $px -minwidth [expr {[font measure AseLabelFont [$tv heading $c -text]] + 18}]}
  }
}
fitcols $W.body.vars.tv {name VCCGAUSSXX value {agauss(1.8, 'ABSVAR', 1)}}
fitcols $W.body.ana.tv  {num 8888 type transient enable Enable args {step=10n stop=200u}}
fitcols $W.body.outs.tv {name TEMPERATXX value {1.177085e+00} plot Plot save Save saveopts {Save Options}}
catch {$W.body.ana.tv  column args -stretch 1}
catch {$W.body.vars.tv column value -stretch 1}
catch {$W.body.outs.tv column saveopts -stretch 1}
foreach c {name num type enable plot save} { catch {$W.body.vars.tv column $c -stretch 0} }
catch {$W.body.ana.tv column num -stretch 0 -anchor e -width 34}
catch {$W.body.ana.tv column enable -stretch 0 -anchor center}
catch {$W.body.outs.tv column plot -stretch 0 -anchor center}
catch {$W.body.outs.tv column save -stretch 0 -anchor center}
pause 400
shotw ase_preview $W
wm geometry $W 560x360 ; pause 700 ; shotw ase_preview_small $W
wm geometry $W 798x502 ; pause 500
catch {ase::ui::simulators_dialog $key} ; pause 900 ; shotw simulators_preview $W.simdlg
catch {destroy $W.simdlg}
foreach f {AseLabelFont AseEntryFont AseMonoFont} {
  puts "FONT $f -> [font actual $f -family]/[font actual $f -size]/[font actual $f -weight] linespace=[font metrics $f -linespace]"
}
puts "DONE"
