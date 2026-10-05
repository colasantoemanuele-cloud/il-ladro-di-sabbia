"""Prototipo dell'economia "impero di sabbia" (direzione A), versione 2.

Non fa parte del gioco: serve a tarare i numeri prima di scriverli in
GDScript. Unità: ore di sabbia. Il tempo avanza a fasce di 6 ore; ogni fascia
costa 6 ore a Sirio e 6 a Sara. Sirio fa UNA cosa per fascia, poi la città
gira: i giri rendono, il calore sale, i rischi si risolvono, Sara può avere
una crisi.

Idea centrale: in questo mondo la sabbia si cede solo volontariamente, anche
sotto minaccia. Un impero è una rete di PERSONE che ti cedono ore con
regolarità. Ogni giro cresce in proporzione a quanto è già grande (i debitori
portano debitori, i fedeli portano fedeli), ma più è grande più scotta.

Uso: python3 tools/prototipo/impero.py [run_per_strategia]
"""
import random
import statistics
import sys

ORE_FASCIA = 6
GIORNI = 21
FASCE = GIORNI * 4
SIRIO_INIZIALE = 24.0
SARA_INIZIALE = GIORNI * 24.0
ORE_ANNO = 8760.0
POPOLAZIONE = 40000

# tributo: ore per persona per fascia. crescita: persone aggiunte per azione
# (base + percentuale della dimensione). costo: ore per persona aggiunta.
# calore: polizia/rivali/fama generati per persona per fascia.
GIRI = {
    "usura":       {"tributo": 0.40, "base": 4, "perc": 0.18, "costo": 2.0,  "rischio": 0.10, "polizia": 0.0030,  "rivali": 0.0,    "fama": 0.0,    "karma": -1, "perdita": 0.010},
    "protezione":  {"tributo": 0.90, "base": 3, "perc": 0.20, "costo": 1.0,  "rischio": 0.30, "polizia": 0.0020,  "rivali": 0.0040, "fama": 0.0,    "karma": -2, "perdita": 0.0, "uomini_per": 25},
    "bische":      {"tributo": 3.50, "base": 1, "perc": 0.15, "costo": 10.0, "rischio": 0.20, "polizia": 0.0300,  "rivali": 0.0080, "fama": 0.0,    "karma": -1, "perdita": 0.0, "uomini_per": 6},
    "culto":       {"tributo": 0.15, "base": 5, "perc": 0.22, "costo": 0.4,  "rischio": 0.25, "polizia": 0.0,     "rivali": 0.0,    "fama": 0.0012, "karma": -1, "perdita": 0.002},
    "cooperativa": {"tributo": 0.25, "base": 5, "perc": 0.15, "costo": 1.5,  "rischio": 0.05, "polizia": -0.0010, "rivali": 0.0,    "fama": 0.0004, "karma": 1,  "perdita": 0.0},
}
LUOGOTENENTE = {"costo": 20.0, "crescita": 0.07, "cresta": 0.15, "tradimento": 0.004}


class Run:
    def __init__(self, seme):
        self.r = random.Random(seme)
        self.S = SIRIO_INIZIALE + 30.0
        self.debito_rate = 8
        self.F = SARA_INIZIALE
        self.t = 0
        self.giri = {g: 0.0 for g in GIRI}
        self.luog = {g: False for g in GIRI}
        self.controllo = {g: 1.0 for g in GIRI}
        self.uomini = 0
        self.informatore = False
        self.polizia = 0.0
        self.rivalita = 0.0
        self.fama = 0.0
        self.karma = 0.0
        self.sveglio = 0
        self.ultima_visita = -99
        self.fine = ""
        self.picco_flusso = 0.0
        self.ultimo_lavoretto = -99

    def giorno(self):
        return self.t // 4 + 1

    def persone(self):
        return sum(self.giri.values())

    def tributo(self, g):
        d = GIRI[g]
        n = self.giri[g]
        if "uomini_per" in d:
            n = min(n, self.uomini * d["uomini_per"] + d["uomini_per"])
        t = n * d["tributo"] * self.controllo[g]
        if self.luog[g]:
            t *= 1 - LUOGOTENENTE["cresta"]
        return t

    def flusso(self):
        return sum(self.tributo(g) for g in GIRI) - self.uomini * 0.8

    def mod(self):
        m = 0
        if self.sveglio >= 6:
            m -= 2
        elif self.sveglio >= 4:
            m -= 1
        return m

    def tiro(self, rischio, extra=0):
        cd = 1 + round(rischio * 20)
        n = self.r.randint(1, 20)
        if n == 20:
            return True
        if n == 1:
            return False
        return n + self.mod() + extra >= cd

    # ------------------------------------------------------------- azioni
    def azioni(self):
        a = ["colpo", "lavoro", "dormi", "visita"]
        if self.t - self.ultimo_lavoretto >= 4:
            a.append("lavoretto")
        for g, d in GIRI.items():
            costo_min = d["costo"] * (d["base"] + d["perc"] * self.giri[g])
            if self.S - costo_min > 18:
                a.append("cresci:" + g)
            if self.giri[g] >= 8 and not self.luog[g] and self.S > LUOGOTENENTE["costo"] + 8 and self.uomini >= 1:
                a.append("luogotenente:" + g)
            if self.giri[g] > 0 and self.controllo[g] < 0.8 and not self.luog[g]:
                a.append("giro:" + g)
        if self.S > 14:
            a.append("recluta")
        if self.S > 20:
            a += ["corrompi", "tributo"]
        if not self.informatore and self.S > 40:
            a.append("informatore")
        if self.uomini >= 3 and self.S > 10:
            a.append("colpo_grosso")
        return a

    def esegui(self, a):
        if a == "dormi":
            self.sveglio = 0
            return
        self.sveglio += 1
        if a == "lavoro":
            self.S += 7
            self.karma += 1
        elif a == "lavoretto":
            self.ultimo_lavoretto = self.t
            self.S += 16
            self.karma -= 1
        elif a == "colpo":
            if self.tiro(0.20):
                self.S += self.r.uniform(8, 22)
            else:
                self.polizia += 6
            self.karma -= 2
        elif a == "colpo_grosso":
            if self.tiro(0.45, self.uomini // 3):
                self.S += self.r.uniform(40, 90) * (1 + self.uomini / 5)
            else:
                self.polizia += 20
                self.uomini = max(0, self.uomini - 1)
            self.karma -= 4
        elif a == "visita":
            self.ultima_visita = self.t
            self.karma += 1
        elif a == "recluta":
            self.S -= 10
            self.uomini += 1
        elif a == "corrompi":
            self.S -= 15 + 0.05 * max(self.flusso(), 0)
            self.polizia = max(0.0, self.polizia - 35)
        elif a == "tributo":
            self.S -= 15 + 0.05 * max(self.flusso(), 0)
            self.rivalita = max(0.0, self.rivalita - 35)
        elif a == "informatore":
            self.S -= 40
            self.informatore = True
        elif a.startswith("cresci:"):
            g = a.split(":")[1]
            d = GIRI[g]
            nuove = d["base"] + d["perc"] * self.giri[g]
            self.S -= d["costo"] * nuove
            if self.tiro(d["rischio"]):
                nuove *= self.r.uniform(0.8, 1.2)
                self.giri[g] = min(self.giri[g] + nuove, POPOLAZIONE)
                self.controllo[g] = min(1.0, self.controllo[g] + 0.2)
            self.karma += d["karma"]
        elif a.startswith("luogotenente:"):
            g = a.split(":")[1]
            self.S -= LUOGOTENENTE["costo"]
            self.luog[g] = True
            self.uomini -= 1
        elif a.startswith("giro:"):
            g = a.split(":")[1]
            self.controllo[g] = 1.0
            self.S += 0.3 * self.tributo(g)

    # ------------------------------------------------------------- mondo
    def tick(self):
        self.S -= ORE_FASCIA
        self.F -= ORE_FASCIA
        if self.t >= 8 and self.debito_rate > 0:
            self.S -= 5.0
            self.debito_rate -= 1
        self.S += self.flusso()
        self.picco_flusso = max(self.picco_flusso, self.flusso())
        riduzione = 0.6 if self.informatore else 1.0
        for g, d in GIRI.items():
            n = self.giri[g]
            if n <= 0:
                continue
            self.polizia = max(0.0, self.polizia + n * d["polizia"] * riduzione)
            self.rivalita += n * d["rivali"]
            self.fama += n * d["fama"]
            self.giri[g] = n * (1 - d["perdita"])
            if self.luog[g]:
                self.giri[g] = min(self.giri[g] * (1 + LUOGOTENENTE["crescita"]), POPOLAZIONE)
                if self.r.random() < LUOGOTENENTE["tradimento"]:
                    self.giri[g] *= 0.5
                    self.luog[g] = False
                self.controllo[g] = max(self.controllo[g], 0.9)
            else:
                self.controllo[g] = max(0.6, self.controllo[g] - 0.015)
        # retata: colpisce il giro illegale che scotta di più
        if self.r.random() < self.polizia / 800:
            illegali = [g for g in ("bische", "protezione", "usura") if self.giri[g] > 0]
            if illegali:
                g = max(illegali, key=lambda x: self.giri[x] * GIRI[x]["polizia"])
                self.giri[g] *= 0.5
                self.luog[g] = False
            self.polizia *= 0.6
        # rivali
        if self.r.random() < self.rivalita / 900:
            difesa = self.uomini >= 3 and self.r.random() < 0.5
            if not difesa:
                self.giri["protezione"] *= 0.6
                self.giri["bische"] *= 0.7
                self.uomini = max(0, self.uomini - 1)
            self.rivalita *= 0.7
        # scandalo
        if self.r.random() < self.fama / 1500:
            self.giri["culto"] *= 0.4
            self.fama *= 0.5
        self.polizia = max(0.0, self.polizia - 1.0)
        self.rivalita = max(0.0, self.rivalita - 0.5)
        # Sara
        p = 0.004 * self.giorno()
        if self.t - self.ultima_visita < 8:
            p *= 0.5
        if self.r.random() < p:
            self.F -= self.r.uniform(12, 24) * (1 + self.giorno() / 5)
        self.t += 1
        if self.S <= 0:
            self.fine = "sirio"
        elif self.F <= 0:
            self.fine = "sara"

    def dona(self, quota):
        x = self.S * quota
        self.S -= x
        self.F += x
        self.fine = "dono"


# ------------------------------------------------------------------ bot

def scegli(run, prof):
    """Bot a regole che gioca come una persona ragionevole: sopravvive, dorme,
    visita Sara, raffredda il calore, poi fa crescere i giri nell'ordine delle
    sue preferenze, mettendo un luogotenente quando un giro è avviato."""
    az = set(run.azioni())
    criminale = prof.get("crimine", 0) > VIETA / 2
    if run.sveglio >= 5 and run.S > 8:
        return "dormi"
    if run.S < 20:
        if criminale and "lavoretto" in az:
            return "lavoretto"
        return "colpo" if criminale else "lavoro"
    if run.t - run.ultima_visita >= 10:
        return "visita"
    if run.polizia > 40 and "corrompi" in az:
        return "corrompi"
    if run.rivalita > 40 and "tributo" in az:
        return "tributo"
    for g in prof.get("ordine", list(GIRI)):
        if f"giro:{g}" in az and run.controllo[g] < 0.6:
            return f"giro:{g}"
    for g in prof.get("ordine", list(GIRI)):
        if run.giri[g] >= 8 and not run.luog[g] and run.flusso() > 12:
            if run.uomini < 1 + (1 if g in ("protezione", "bische") else 0):
                return "recluta" if "recluta" in az else "lavoretto"
            if f"luogotenente:{g}" in az:
                return f"luogotenente:{g}"
        if g in ("protezione", "bische"):
            serve = run.giri["protezione"] / 25 + run.giri["bische"] / 6
            if run.uomini < serve and "recluta" in az:
                return "recluta"
        if f"cresci:{g}" in az and (not run.luog[g] or run.giri[g] < prof.get("tetto", 1e9)):
            return f"cresci:{g}"
    if criminale and "colpo_grosso" in az and run.uomini >= 4:
        return "colpo_grosso"
    if "informatore" in az and run.polizia > 15:
        return "informatore"
    if criminale and "lavoretto" in az:
        return "lavoretto"
    return "lavoro"


def gioca(seme, prof, donare):
    run = Run(seme)
    while run.fine == "" and run.t < FASCE:
        if donare(run):
            run.dona(prof.get("quota", 0.9))
            break
        if prof.get("rumore", 0) > 1000:
            scelta = run.r.choice(run.azioni())
        else:
            scelta = scegli(run, prof)
        run.esegui(scelta)
        run.tick()
    if run.fine == "":
        run.fine = "tempo"
    return run


VIETA = -1e9
DONA_TARDI = lambda r: r.F < 60 or (r.S < 10 and r.t > 8)


def strategia(solo=None, **extra):
    prof = dict(extra)
    if solo is not None:
        for g in GIRI:
            if g not in solo:
                prof[g] = VIETA
    return prof


STRATEGIE = {
    "ladro (solo colpi)": ({"ordine": []}, DONA_TARDI),
    "onesto (cooperativa)": ({"ordine": ["cooperativa"], "crimine": VIETA}, DONA_TARDI),
    "usuraio": ({"ordine": ["usura"]}, DONA_TARDI),
    "boss (protezione)": ({"ordine": ["protezione"]}, DONA_TARDI),
    "biscazziere": ({"ordine": ["bische"]}, DONA_TARDI),
    "predicatore": ({"ordine": ["culto"]}, DONA_TARDI),
    "impero (usura, culto, protezione)": ({"ordine": ["usura", "culto", "protezione"], "tetto": 150}, DONA_TARDI),
    "impero, dona al giorno 14": ({"ordine": ["usura", "culto", "protezione"], "tetto": 150}, lambda r: r.giorno() >= 14 or r.F < 60),
    "casuale": ({"rumore": 1e4}, DONA_TARDI),
}


def riassunto(n, seme0=1000):
    print(f"{'strategia':34s} {'Sara anni':>9s} {'mediana':>8s} {'p90':>7s} {'max':>8s} {'flusso picco':>12s}  sirio†  sara†  dono")
    for nome, (prof, donare) in STRATEGIE.items():
        anni, picchi = [], []
        fini = {"sirio": 0, "sara": 0, "dono": 0, "tempo": 0}
        for i in range(n):
            r = gioca(seme0 + i, prof, donare)
            anni.append(r.F / ORE_ANNO if r.fine == "dono" else 0.0)
            picchi.append(r.picco_flusso)
            fini[r.fine] += 1
        anni.sort()
        print(f"{nome:34s} {statistics.mean(anni):9.2f} {anni[n // 2]:8.2f} {anni[int(n * .9)]:7.2f} {anni[-1]:8.2f} {statistics.median(picchi):12.0f}"
              f"  {fini['sirio'] / n:5.0%}  {fini['sara'] / n:5.0%}  {fini['dono'] / n:4.0%}")


if __name__ == "__main__":
    riassunto(int(sys.argv[1]) if len(sys.argv) > 1 else 300)
