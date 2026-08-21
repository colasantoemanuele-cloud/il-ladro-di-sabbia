extends Node
## Entry point del gioco. Fase 1: verifica solo che i dati si carichino.
## Verra' esteso nelle fasi successive con il loop testuale giocabile.


func _ready() -> void:
	print("Il ladro di sabbia — Fase 1: verifica dati")
	print("Azioni caricate: %d" % ActionDatabase.azioni.size())
	print("Salario mediano: %.2f EUR/ora" % ActionDatabase.salario_mediano_eur_ora)
	print("Categorie: %s" % ", ".join(ActionDatabase.get_categorie()))
	get_tree().quit()
