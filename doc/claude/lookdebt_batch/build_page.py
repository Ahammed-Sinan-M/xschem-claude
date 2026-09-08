import json, base64, html, os
SP = os.path.dirname(os.path.abspath(__file__))
debts = json.load(open(SP + '/debts.json'))
by = {d['id']: d for d in debts}

SHOTS = {
 'the_Results_Display_Window_itself__item_B3_': [('rdw_plain.png','The window as it opens, with two device blocks pushed through the shipped renderer.')],
 'the_RDW_engineering_notation':               [('rdw_plain.png','id 9.87u, gm 198u, gds 880n, vth 0.448 — engineering suffixes, and the value column left-aligned after the colon.')],
 'the_RDW_line_cursor_shade':                  [('rdw_cursor.png','The cursor resting on the gds row of the first block. This is the grey the buttons act on.')],
 'rdw_1355_chrome_and_dialog':                 [('rdw_plain.png','The list-name line sits above the pane. Note what it says — see the finding at the top of this page.')],
 'the_RDW_s_five_new_sentences__item_B2d_':    [('rdw_refusal.png','Two refusals in one pane: the malformed-answer sentence naming ngspice, and the no-raw sentence.')],
 'rdw_1365_status_scroll':                     [('rdw_status.png','A 190-character verdict on the status surface, wrapped to two lines with nothing cut. Captured on :99 — the question is what your own server does.')],
 'the_RDW_at_text_size_20_and_at_6__and_the_aA_glyph_and_its_toolt': [
     ('rdw_size20.png','Six presses up. The pane font grows; the chrome line and the buttons do not.'),
     ('rdw_size6.png','Six presses down from the same start.')],
 '1371_the_Case_chooser_and_the_widened_row_editor': [('ase_simdlg.png','Your own ngspice-ver50 entry, read live from ~/.xschem/ase_simulators. The Program column stops at build-ver_ — the path is cut.')],
}

def b64(p):
    with open(SP + '/shots/' + p,'rb') as f:
        return 'data:image/png;base64,' + base64.b64encode(f.read()).decode()

CLASS_LABEL = {'canvas':'schematic','widget':'window','text':'wording','hands':'your bench','moot':'retire'}

photographed = [d for d in debts if d['id'] in SHOTS]
photo_ids = set(SHOTS)
ready     = [d for d in debts if d['klass'] in ('canvas','widget','text') and d['id'] not in photo_ids]
hands     = [d for d in debts if d['klass']=='hands' and d['id'] not in photo_ids]
moot      = [d for d in debts if d['klass']=='moot']

def esc(s): return html.escape(s or '')

def entry(d, shots=None):
    o = []
    o.append('<article class="e e--%s">' % d['klass'])
    o.append('<header class="e-head">')
    o.append('<p class="e-q">%s</p>' % esc(d['question']))
    o.append('<p class="e-id"><code>%s</code></p>' % esc(d['id']))
    o.append('</header>')
    if shots:
        for fn, cap in shots:
            o.append('<figure class="shot"><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>' % (b64(fn), esc(d['title']), esc(cap)))
    o.append('<dl class="ver">')
    o.append('<dt>Right</dt><dd>%s</dd>' % esc(d['fine']))
    o.append('<dt>Wrong</dt><dd>%s</dd>' % esc(d['wrong']))
    o.append('</dl>')
    if d['klass'] != 'moot':
        o.append('<details class="rec"><summary>%s</summary><pre>%s</pre></details>' % (
            'Steps' if d['klass']=='hands' else 'How this was posed', esc(d['recipe'])))
    else:
        o.append('<p class="why">%s</p>' % esc(d['recipe']))
    o.append('<p class="clear"><code>owed.sh clear look %s</code></p>' % esc(d['id']))
    o.append('</article>')
    return '\n'.join(o)

def section(title, kicker, items, shots_for=None):
    o = ['<section class="sec">', '<div class="sec-head"><h2>%s</h2><p>%s</p></div>' % (esc(title), kicker)]
    for d in items:
        o.append(entry(d, SHOTS.get(d['id']) if shots_for else None))
    o.append('</section>')
    return '\n'.join(o)

BODY = []
BODY.append(section('Photographed', 'The picture is on this page. Read it, decide, and clear the line.', photographed, True))
BODY.append(section('One command away', 'The pose is written and checked against the source; nobody has run it yet. Each block below is the exact command.', ready))
BODY.append(section('Your bench only', 'A gesture, a clipboard, a focus change, or your own VcXsrv server. No screenshot can settle these — the steps are six or fewer.', hands))
BODY.append(section('Recommended to retire', 'Asked twice, or already answered by a commit in the tree. Every claim below was checked against the issue file and the commit named. Clearing these is still yours.', moot))

open(SP + '/lookdebt_digest.html','w').write(open(SP + '/page_shell.html').read().replace('<!--BODY-->', '\n'.join(BODY)))
print('entries: photographed %d, ready %d, hands %d, moot %d, total %d' % (len(photographed), len(ready), len(hands), len(moot), len(photographed)+len(ready)+len(hands)+len(moot)))
