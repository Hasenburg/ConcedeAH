local _, ns = ...

ns.SPELL_ID_DEATH_CLIPS = 30882


ns.CreateMagicLink = function(spellID, label, color)
    color = color or "ff71d5ff"
    return "|c"..color.."|Hspell:"..spellID.."|h["..label.."]|h|r"
end





