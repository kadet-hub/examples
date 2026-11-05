# House rules over one target's compiled output, run as
#   conftest test --combine compiled/<target>
# --combine hands every file of the target to the rules at once, so a rule
# can look for an object in another file.
package main

# Every object of the target with the file it came from. A file holds one
# document or, as a list, several.
objects contains [f.path, o] if {
	some f in input
	is_object(f.contents)
	o := f.contents
}

objects contains [f.path, o] if {
	some f in input
	is_array(f.contents)
	some o in f.contents
	is_object(o)
}

# Pod specs sit at different depths per kind; any containers list counts.
deny contains msg if {
	some [path, o] in objects
	walk(o, [p, list])
	p[count(p) - 1] in {"containers", "initContainers", "ephemeralContainers"}
	some c in list
	not contains(c.image, "@sha256:")
	msg := sprintf("%s: %s %s, container %s: image %s is not pinned by digest", [path, o.kind, name(o), c.name, c.image])
}

deny contains msg if {
	some [path, o] in objects
	o.kind == "Deployment"
	o.spec.replicas > 1
	not covered(o)
	msg := sprintf("%s: Deployment %s runs %d replicas and no PodDisruptionBudget selects its pods", [path, name(o), o.spec.replicas])
}

covered(d) if {
	some [_, pdb] in objects
	pdb.kind == "PodDisruptionBudget"
	pdb.metadata.namespace == d.metadata.namespace
	count(pdb.spec.selector.matchLabels) > 0
	every k, v in pdb.spec.selector.matchLabels {
		d.spec.template.metadata.labels[k] == v
	}
}

name(o) := sprintf("%s/%s", [o.metadata.namespace, o.metadata.name])

name(o) := o.metadata.name if not o.metadata.namespace
