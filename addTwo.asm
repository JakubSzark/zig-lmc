# Adds Two Numbers
start:
    # Tabbed
    INP # Inline Comment
    STA $99
    INP
    ADD $99
    ADD ten
    BRA subtract

subtract:
    SUB one
    OUT
    BRP subtract
    BRZ end

end:
    HLT
    
one: DAT 1
ten: DAT 10
# Last Line