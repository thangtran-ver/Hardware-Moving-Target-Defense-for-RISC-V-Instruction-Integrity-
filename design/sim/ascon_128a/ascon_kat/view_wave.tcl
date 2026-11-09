# Tu dong them tin hieu, doi sang hex va zoom cho wave.vcd.   Chay:  gtkwave -S view_wave.tcl wave.vcd
# (Co the dat bien moi truong ZOOM_FROM_NS / ZOOM_TO_NS de zoom vao 1 doan thoi gian.)

# --- danh sach tin hieu can xem (theo thu tu hien thi) ---
set want {
  clk rst_n start ad_valid ad_ready tag_out
}

# --- tim ten day du trong VCD (co the co tien to TOP. neu do Verilator tao) ---
set nfacs [gtkwave::getNumFacs]
for {set i 0} {$i < $nfacs} {incr i} { lappend facs [gtkwave::getFacName $i] }

set added 0
foreach s $want {
    set pat "(^|\\.)tb_ascon_kat\\.[string map {. \\.} $s](\\\[\[0-9\]+:0\\\])?$"
    foreach f $facs {
        if {[regexp $pat $f]} {
            gtkwave::addSignalsFromList [list $f]
            incr added
            break
        }
    }
}
puts "view_wave.tcl: da them $added tin hieu"

# --- dinh dang hex cho tat ca (bit don van hien 0/1) ---
gtkwave::/Edit/Highlight_All
gtkwave::/Edit/Data_Format/Hex
gtkwave::/Edit/UnHighlight_All

# --- zoom ---
if {[info exists ::env(ZOOM_FROM_NS)] && [info exists ::env(ZOOM_TO_NS)]} {
    gtkwave::setZoomRangeTimes [expr {$::env(ZOOM_FROM_NS) * 1000}] [expr {$::env(ZOOM_TO_NS) * 1000}]
} else {
    gtkwave::/Time/Zoom/Zoom_Full
}
