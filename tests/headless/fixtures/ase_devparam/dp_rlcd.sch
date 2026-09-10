v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {devices/res.sym} 0 0 0 0 {name=R1 value=1k}
C {devices/lab_pin.sym} 0 -30 0 0 {name=l1 lab=RA}
C {devices/lab_pin.sym} 0 30 0 0 {name=l2 lab=RB}
C {devices/capa.sym} 200 0 0 0 {name=C1 value=1n}
C {devices/lab_pin.sym} 200 -30 0 0 {name=l3 lab=CA}
C {devices/lab_pin.sym} 200 30 0 0 {name=l4 lab=CB}
C {devices/ind.sym} 400 0 0 0 {name=L1 value=1u}
C {devices/lab_pin.sym} 400 -30 0 0 {name=l5 lab=LA}
C {devices/lab_pin.sym} 400 30 0 0 {name=l6 lab=LB}
C {devices/diode.sym} 600 0 0 0 {name=D1 model=diode}
C {devices/lab_pin.sym} 600 -30 0 0 {name=l7 lab=DA}
C {devices/lab_pin.sym} 600 30 0 0 {name=l8 lab=DB}
C {dp_pdkres.sym} 800 0 0 0 {name=R2 model=dpres_1v8 W=1 L=0.15 spiceprefix=X}
C {devices/res.sym} 1000 0 0 0 {name=R3 value=1k}
N 1000 -30 1000 -100 {}
N 1000 30 1000 100 {}
