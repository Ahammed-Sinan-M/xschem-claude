/* winshot.c -- grab an X window (or the root) to a PNG.
 *
 * WHY THIS EXISTS
 *
 * This box has no screenshot tool at all: no import(1), no xwd, no scrot, no
 * ffmpeg, no PIL, no Tk Img.  xschem can export its own canvas
 * (`xschem print png`, and the net_hilight_dump_pixmap test hook), but neither
 * of those can show a Tk DIALOG -- and most of the tree's outstanding "look"
 * debts are about dialogs, panes and status lines, not about the schematic.
 * Without this, a pixel deliverable can only ever be described in prose, which
 * is exactly the failure mode the owed-ledger's `look` class exists to prevent.
 *
 * It is deliberately a standalone one-file tool compiled on demand by
 * winshot.sh, NOT a new object in src/: adding a file there obliges a
 * Makefile.in edit plus a ./configure re-run, and a stale generated src/Makefile
 * is invisible in-tree and fatal once installed (CLAUDE.md, issue 0424).
 *
 * Usage:
 *   winshot out.png                     root window of $DISPLAY
 *   winshot out.png -name "Results"     first window whose WM_NAME contains it
 *   winshot out.png -id 0x2400007       an explicit window id
 *   winshot out.png -d :99 -name Case -raise -settle 300
 *
 * Exit codes: 0 ok, 2 no such window, 3 X error, 4 write error, 1 usage.
 */
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char *g_match = NULL;
static Window g_found = 0;

/* Depth-first walk. Matches WM_NAME (and _NET_WM_NAME) by substring, and only
 * accepts a VIEWABLE window: an unmapped match would grab as garbage or fail,
 * and a silent garbage PNG is worse than no PNG. */
static void find_win(Display *d, Window w, Atom netname, Atom utf8)
{
  Window root, parent, *kids = NULL;
  unsigned int n = 0, i;
  char *name = NULL;
  XWindowAttributes wa;

  if(g_found) return;
  if(XGetWindowAttributes(d, w, &wa) && wa.map_state == IsViewable) {
    int hit = 0;
    if(XFetchName(d, w, &name) && name) {
      if(strstr(name, g_match)) hit = 1;
      XFree(name); name = NULL;
    }
    if(!hit) {                      /* modern toolkits set _NET_WM_NAME only */
      Atom type; int fmt; unsigned long nitems, after; unsigned char *prop = NULL;
      if(XGetWindowProperty(d, w, netname, 0, 1024, False, utf8, &type, &fmt,
                            &nitems, &after, &prop) == Success && prop) {
        if(strstr((char *)prop, g_match)) hit = 1;
        XFree(prop);
      }
    }
    if(hit && wa.width > 1 && wa.height > 1) { g_found = w; return; }
  }
  if(XQueryTree(d, w, &root, &parent, &kids, &n)) {
    for(i = 0; i < n && !g_found; i++) find_win(d, kids[i], netname, utf8);
    if(kids) XFree(kids);
  }
}

static int shift_of(unsigned long mask)
{
  int s = 0;
  if(!mask) return 0;
  while(!(mask & 1)) { mask >>= 1; s++; }
  return s;
}
static int width_of(unsigned long mask)
{
  int w = 0;
  if(!mask) return 8;
  while(!(mask & 1)) mask >>= 1;
  while(mask & 1) { mask >>= 1; w++; }
  return w;
}

int main(int argc, char **argv)
{
  const char *out = NULL, *dpyname = NULL;
  Window wid = 0;
  int use_root = 0, do_raise = 0, settle_ms = 120, i;
  Display *d;
  Window target, root;
  XWindowAttributes wa;
  XImage *img;
  Atom netname, utf8;
  FILE *fp;
  png_structp png;
  png_infop info;
  png_bytep row;
  int rs, gs, bs, rw, gw, bw, x, y;

  for(i = 1; i < argc; i++) {
    if(argv[i][0] != '-') { if(!out) out = argv[i]; else { fprintf(stderr, "winshot: extra arg %s\n", argv[i]); return 1; } }
    else if(!strcmp(argv[i], "-d") && i + 1 < argc) dpyname = argv[++i];
    else if(!strcmp(argv[i], "-name") && i + 1 < argc) g_match = argv[++i];
    else if(!strcmp(argv[i], "-id") && i + 1 < argc) wid = (Window)strtoul(argv[++i], NULL, 0);
    else if(!strcmp(argv[i], "-root")) use_root = 1;
    else if(!strcmp(argv[i], "-raise")) do_raise = 1;
    else if(!strcmp(argv[i], "-settle") && i + 1 < argc) settle_ms = atoi(argv[++i]);
    else { fprintf(stderr, "winshot: unknown option %s\n", argv[i]); return 1; }
  }
  if(!out) { fprintf(stderr, "usage: winshot out.png [-d DPY] [-name SUB | -id ID | -root] [-raise] [-settle MS]\n"); return 1; }

  d = XOpenDisplay(dpyname);
  if(!d) { fprintf(stderr, "winshot: cannot open display %s\n", dpyname ? dpyname : (getenv("DISPLAY") ? getenv("DISPLAY") : "(unset)")); return 3; }
  root = DefaultRootWindow(d);
  netname = XInternAtom(d, "_NET_WM_NAME", False);
  utf8 = XInternAtom(d, "UTF8_STRING", False);

  if(wid) target = wid;
  else if(use_root || !g_match) target = root;
  else {
    find_win(d, root, netname, utf8);
    if(!g_found) { fprintf(stderr, "winshot: no viewable window matching \"%s\"\n", g_match); XCloseDisplay(d); return 2; }
    target = g_found;
  }

  if(do_raise && target != root) { XRaiseWindow(d, target); XSync(d, False); }
  if(settle_ms > 0) usleep((useconds_t)settle_ms * 1000);
  XSync(d, False);

  if(!XGetWindowAttributes(d, target, &wa)) { fprintf(stderr, "winshot: no attributes for window\n"); XCloseDisplay(d); return 3; }
  img = XGetImage(d, target, 0, 0, wa.width, wa.height, AllPlanes, ZPixmap);
  if(!img) { fprintf(stderr, "winshot: XGetImage failed (window obscured, unmapped or offscreen?)\n"); XCloseDisplay(d); return 3; }

  rs = shift_of(img->red_mask); gs = shift_of(img->green_mask); bs = shift_of(img->blue_mask);
  rw = width_of(img->red_mask); gw = width_of(img->green_mask); bw = width_of(img->blue_mask);

  fp = fopen(out, "wb");
  if(!fp) { perror("winshot: fopen"); XDestroyImage(img); XCloseDisplay(d); return 4; }
  png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  info = png_create_info_struct(png);
  if(!png || !info || setjmp(png_jmpbuf(png))) { fprintf(stderr, "winshot: png init failed\n"); fclose(fp); return 4; }
  png_init_io(png, fp);
  png_set_IHDR(png, info, img->width, img->height, 8, PNG_COLOR_TYPE_RGB,
               PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
  png_write_info(png, info);
  row = (png_bytep)malloc((size_t)img->width * 3);
  if(!row) { fprintf(stderr, "winshot: out of memory\n"); fclose(fp); return 4; }
  for(y = 0; y < img->height; y++) {
    for(x = 0; x < img->width; x++) {
      unsigned long p = XGetPixel(img, x, y);
      unsigned long r = (p & img->red_mask) >> rs;
      unsigned long g = (p & img->green_mask) >> gs;
      unsigned long b = (p & img->blue_mask) >> bs;
      /* scale each channel to 8 bits from whatever width the visual gives */
      row[x * 3 + 0] = (png_byte)(rw >= 8 ? (r >> (rw - 8)) : (r << (8 - rw)));
      row[x * 3 + 1] = (png_byte)(gw >= 8 ? (g >> (gw - 8)) : (g << (8 - gw)));
      row[x * 3 + 2] = (png_byte)(bw >= 8 ? (b >> (bw - 8)) : (b << (8 - bw)));
    }
    png_write_row(png, row);
  }
  png_write_end(png, NULL);
  free(row);
  fclose(fp);
  png_destroy_write_struct(&png, &info);
  XDestroyImage(img);
  XCloseDisplay(d);
  fprintf(stdout, "%s %dx%d\n", out, wa.width, wa.height);
  return 0;
}
