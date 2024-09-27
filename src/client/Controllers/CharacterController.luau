local CharacterController = {}

function CharacterController:OnInit()
  task.wait(10)
end

function CharacterController:OnLocalCharacter(Character)
  print("Character added", Character)
end

return CharacterController