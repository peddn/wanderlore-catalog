-- The author's selection for Wanderlore, to see it before it is built
-- there: every chosen form of a tree, rewritten to the chosen trunk and
-- leaves. The plants world shows these in rows of their own; /auswahl
-- jumps there.
--
-- trunk and leaves name a block: by the number of a tree whose block is
-- meant ("MT-T3"), by the number of a block ("MT3") or by its technical
-- name. A form names a tree by its number; scale enlarges it.

return {
	{
		name = "birch",
		title = "Birke",
		trunk = "MT-T3",
		leaves = "NB-T22",
		forms = {
			{tree = "EB-T20", label = "klein"},
			{tree = "NB-T22", label = "mittel"},
			{tree = "NB-T21", label = "gross"},
			-- Candidates for the elder form, proposed by Claude.
			{tree = "MT-T3", label = "elder_A_MT-T3"},
			{tree = "NB-T21", label = "elder_B_NB-T21_x1.5", scale = 1.5},
			{tree = "NB-T21", label = "elder_C_NB-T21_x2", scale = 2},
		},
	},
}
