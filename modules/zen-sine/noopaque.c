// noopaque : empêche Zen/Firefox de déclarer ses surfaces Wayland opaques
// (wl_surface.set_opaque_region(region) -> set_opaque_region(NULL)), pour que
// le compositeur (niri) respecte l'alpha et puisse flouter derrière la sidebar.
// Contourne la régression Firefox >= 153 (bug 2045222).
// x86-64 uniquement : les requêtes Wayland n'ont que des arguments entiers /
// pointeurs, on les relaie donc tels quels (12 mots).
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>

struct wl_proxy;
struct wl_interface;
union wl_argument { int32_t i; uint32_t u; const char *s; void *o; uint32_t n; void *a; int32_t h; int32_t f; };
typedef const char *(*getclass_t)(struct wl_proxy *);

#define SET_OPAQUE_REGION 4
#define W uintptr_t
#define FWD a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11]

static int is_opaque(struct wl_proxy *p, uint32_t op) {
  /* résolu à l'exécution : la lib est aussi préchargée dans des programmes
   * sans libwayland (le script de lancement bash, par ex.) */
  static getclass_t get_class;
  if (op != SET_OPAQUE_REGION) return 0;
  if (!get_class) get_class = (getclass_t)dlsym(RTLD_DEFAULT, "wl_proxy_get_class");
  return get_class && strcmp(get_class(p), "wl_surface") == 0;
}

typedef struct wl_proxy *(*mflags_t)(struct wl_proxy *, uint32_t, const struct wl_interface *, uint32_t, uint32_t, ...);
struct wl_proxy *wl_proxy_marshal_flags(struct wl_proxy *p, uint32_t op, const struct wl_interface *iface,
                                        uint32_t ver, uint32_t flags, ...) {
  static mflags_t real;
  if (!real) real = (mflags_t)dlsym(RTLD_NEXT, "wl_proxy_marshal_flags");
  W a[12]; va_list ap; va_start(ap, flags);
  for (int i = 0; i < 12; i++) a[i] = va_arg(ap, W);
  va_end(ap);
  if (is_opaque(p, op)) a[0] = 0;
  return real(p, op, iface, ver, flags, FWD);
}

typedef void (*m_t)(struct wl_proxy *, uint32_t, ...);
void wl_proxy_marshal(struct wl_proxy *p, uint32_t op, ...) {
  static m_t real;
  if (!real) real = (m_t)dlsym(RTLD_NEXT, "wl_proxy_marshal");
  W a[12]; va_list ap; va_start(ap, op);
  for (int i = 0; i < 12; i++) a[i] = va_arg(ap, W);
  va_end(ap);
  if (is_opaque(p, op)) a[0] = 0;
  real(p, op, FWD);
}

typedef struct wl_proxy *(*maf_t)(struct wl_proxy *, uint32_t, const struct wl_interface *, uint32_t, uint32_t, union wl_argument *);
struct wl_proxy *wl_proxy_marshal_array_flags(struct wl_proxy *p, uint32_t op, const struct wl_interface *iface,
                                              uint32_t ver, uint32_t flags, union wl_argument *args) {
  static maf_t real;
  if (!real) real = (maf_t)dlsym(RTLD_NEXT, "wl_proxy_marshal_array_flags");
  if (is_opaque(p, op)) args[0].o = 0;
  return real(p, op, iface, ver, flags, args);
}

typedef void (*ma_t)(struct wl_proxy *, uint32_t, union wl_argument *);
void wl_proxy_marshal_array(struct wl_proxy *p, uint32_t op, union wl_argument *args) {
  static ma_t real;
  if (!real) real = (ma_t)dlsym(RTLD_NEXT, "wl_proxy_marshal_array");
  if (is_opaque(p, op)) args[0].o = 0;
  real(p, op, args);
}

