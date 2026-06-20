if DrawingImmediate then
	local ESP = {
		Config = {
			ZIndex = 2,
			Enabled = true,
			ShowHealthBars = true,
			ShowNames = true,
			ShowBoxes = true,
			ShowDistance = true,
			ShowTools = true,
			BoxThickness = 1,
			NameFont = 1,
			FontSize = 12,
			NameColor = Color3.new(1, 1, 1),
			BoxColor = Color3.new(1, 1, 1),
			HealthBarWidth = 2,
			HealthBarHeight = 10,
			MaxDistance = 100,
			ToolIconSize = 16
		},
		Callbacks = {
			getPartsToRenderCallback = nil,
			partToHealthCallback = nil,
			partToToolsToRenderCallback = nil
		},
		_activeObjects = {},
		_signal = nil,
		_connections = {},
		_cache = {
			parts = {},
			health = {},
			tools = {},
			lastUpdate = 0,
			updateInterval = 0.1
		}
	}
	function ESP:WorldToScreen(worldPosition)
		local camera = workspace.CurrentCamera;
		if not camera then
			return nil
		end;
		local vector, onScreen = camera:WorldToViewportPoint(worldPosition)
		if onScreen and vector.Z > 0 then
			return Vector2.new(vector.X, vector.Y), vector.Z
		end;
		return nil, nil
	end;
	function ESP:GetHealthColor(currentHealth, maxHealth)
		if not currentHealth or not maxHealth or maxHealth <= 0 then
			return Color3.new(1, 1, 1)
		end;
		local percent = currentHealth / maxHealth;
		if percent > 0.7 then
			return Color3.new(0, 1, 0)
		elseif percent > 0.3 then
			return Color3.new(1, 1, 0)
		else
			return Color3.new(1, 0, 0)
		end
	end;
	function ESP:GetPartBoxSize(part)
		if not part then
			return 2, 2
		end;
		if part:IsA("Model") then
			local size = part:GetExtentsSize()
			return size.X * 2, size.Y * 2
		end;
		if part:IsA("BasePart") then
			local size = part.Size;
			return size.X, size.Y
		end;
		return 2, 2
	end;
	function ESP:GetPartPosition(part)
		if part:IsA("Model") then
			local primary = part.PrimaryPart;
			if primary then
				return primary.Position
			end;
			local total = Vector3.new(0, 0, 0)
			local count = 0;
			for _, child in ipairs(part:GetDescendants()) do
				if child:IsA("BasePart") then
					total = total + child.Position;
					count = count + 1
				end
			end;
			if count > 0 then
				return total / count
			end;
			return part:GetPivot().Position
		end;
		if part:IsA("BasePart") then
			return part.Position
		end;
		return Vector3.new(0, 0, 0)
	end;
	function ESP:DrawHealthBar(part, screenPos, boxWidth, boxHeight)
		if not self.Config.ShowHealthBars then
			return
		end;
		if not self.Callbacks.partToHealthCallback then
			return
		end;
		local healthInfo = self.Callbacks.partToHealthCallback(part)
		if not healthInfo then
			return
		end;
		local currentHealth = healthInfo.currentHealth or healthInfo[1]
		local maxHealth = healthInfo.maxHealth or healthInfo[2]
		if not currentHealth or not maxHealth or maxHealth <= 0 then
			return
		end;
		local healthPercent = math.clamp(currentHealth / maxHealth, 0, 1)
		local barWidth = boxWidth * healthPercent;
		local barPos = Vector2.new(screenPos.X - (boxWidth / 2), screenPos.Y - boxHeight - self.Config.HealthBarHeight - 2)
		DrawingImmediate.Rectangle(barPos, Vector2.new(boxWidth, self.Config.HealthBarHeight), Color3.new(0.3, 0.3, 0.3), 0.8, 2, 1)
		if barWidth > 0 then
			DrawingImmediate.FilledRectangle(barPos, Vector2.new(barWidth, self.Config.HealthBarHeight), self:GetHealthColor(currentHealth, maxHealth), 1, 2)
		end;
		local healthText = string.format("%.0f/%.0f", currentHealth, maxHealth)
		local textPos = Vector2.new(screenPos.X, barPos.Y - 2)
		DrawingImmediate.OutlinedText(textPos, self.Config.NameFont, self.Config.FontSize - 2, Color3.new(1, 1, 1), 1, Color3.new(0, 0, 0), 1, healthText, true)
	end;
	function ESP:DrawTools(part, screenPos, boxWidth, boxHeight)
		if not self.Config.ShowTools then
			return
		end;
		if not self.Callbacks.partToToolsToRenderCallback then
			return
		end;
		local tools = self.Callbacks.partToToolsToRenderCallback(part)
		if not tools or #tools == 0 then
			return
		end;
		local startX = screenPos.X - (boxWidth / 2)
		local startY = screenPos.Y + boxHeight + 5;
		local iconSize = self.Config.ToolIconSize;
		local spacing = 5;
		for i, tool in ipairs(tools) do
			local toolPart = tool.toolPart or tool[1]
			local toolName = tool.name or tool[2] or "Unknown"
			if toolPart and toolPart:IsA("BasePart") then
				local iconPos = Vector2.new(startX + (i - 1) * (iconSize + spacing), startY)
				DrawingImmediate.FilledRectangle(iconPos, Vector2.new(iconSize, iconSize), Color3.new(0.2, 0.2, 0.2), 0.8, 3)
				DrawingImmediate.Rectangle(iconPos, Vector2.new(iconSize, iconSize), Color3.new(1, 1, 1), 0.5, 3, 1)
				DrawingImmediate.OutlinedText(Vector2.new(iconPos.X + iconSize / 2, iconPos.Y + iconSize + 2), self.Config.NameFont, self.Config.FontSize - 2, Color3.new(1, 1, 1), 1, Color3.new(0, 0, 0), 1, toolName, true)
				local toolScreenPos = self:WorldToScreen(toolPart.Position)
				if toolScreenPos then
					DrawingImmediate.Line(screenPos, toolScreenPos, Color3.new(1, 1, 0), 0.5, 1)
				end
			end
		end
	end;
	function ESP:DrawNameAndDistance(part, screenPos, partName, distance)
		if not self.Config.ShowNames and not self.Config.ShowDistance then
			return
		end;
		local text = ""
		if self.Config.ShowNames then
			text = partName or "Unknown"
		end;
		if self.Config.ShowDistance and distance then
			local distText = string.format(" [%.0fm]", distance)
			text = text .. distText
		end;
		if text ~= "" then
			local textPos = Vector2.new(screenPos.X, screenPos.Y - 25)
			DrawingImmediate.OutlinedText(textPos, self.Config.NameFont, self.Config.FontSize, self.Config.NameColor, 1, Color3.new(0, 0, 0), 1, text, true)
		end
	end;
	function ESP:DrawBox(part, screenPos, boxWidth, boxHeight, distance)
		if not self.Config.ShowBoxes then
			return
		end;
		local topLeft = Vector2.new(screenPos.X - (boxWidth / 2), screenPos.Y - boxHeight)
		local boxColor = self.Config.BoxColor;
		if self.Config.ShowHealthBars and self.Callbacks.partToHealthCallback then
			local healthInfo = self.Callbacks.partToHealthCallback(part)
			if healthInfo then
				local currentHealth = healthInfo.currentHealth or healthInfo[1]
				local maxHealth = healthInfo.maxHealth or healthInfo[2]
				if currentHealth and maxHealth then
					boxColor = self:GetHealthColor(currentHealth, maxHealth)
				end
			end
		end;
		DrawingImmediate.Rectangle(topLeft, Vector2.new(boxWidth, boxHeight), boxColor, 1, 0, self.Config.BoxThickness)
		local accentSize = math.min(10, boxWidth * 0.2)
		local accentColor = Color3.new(1, 1, 1)
		DrawingImmediate.Line(topLeft, Vector2.new(topLeft.X + accentSize, topLeft.Y), accentColor, 0.8, 2)
		DrawingImmediate.Line(topLeft, Vector2.new(topLeft.X, topLeft.Y + accentSize), accentColor, 0.8, 2)
		local topRight = Vector2.new(topLeft.X + boxWidth, topLeft.Y)
		DrawingImmediate.Line(Vector2.new(topRight.X - accentSize, topRight.Y), topRight, accentColor, 0.8, 2)
		DrawingImmediate.Line(topRight, Vector2.new(topRight.X, topRight.Y + accentSize), accentColor, 0.8, 2)
		local bottomLeft = Vector2.new(topLeft.X, topLeft.Y + boxHeight)
		DrawingImmediate.Line(bottomLeft, Vector2.new(bottomLeft.X + accentSize, bottomLeft.Y), accentColor, 0.8, 2)
		DrawingImmediate.Line(bottomLeft, Vector2.new(bottomLeft.X, bottomLeft.Y - accentSize), accentColor, 0.8, 2)
		local bottomRight = Vector2.new(topLeft.X + boxWidth, topLeft.Y + boxHeight)
		DrawingImmediate.Line(Vector2.new(bottomRight.X - accentSize, bottomRight.Y), bottomRight, accentColor, 0.8, 2)
		DrawingImmediate.Line(bottomRight, Vector2.new(bottomRight.X, bottomRight.Y - accentSize), accentColor, 0.8, 2)
	end;
	function ESP:_UpdateCache()
		local currentTime = tick()
		if currentTime - self._cache.lastUpdate < self._cache.updateInterval then
			return
		end;
		self._cache.lastUpdate = currentTime;
		self._cache.parts = {}
		self._cache.health = {}
		self._cache.tools = {}
		if self.Callbacks.getPartsToRenderCallback then
			local parts = self.Callbacks.getPartsToRenderCallback()
			if parts then
				for i, part in ipairs(parts) do
					self._cache.parts[#self._cache.parts + 1] = part;
					if self.Callbacks.partToHealthCallback then
						local health = self.Callbacks.partToHealthCallback(part)
						if health then
							self._cache.health[part] = health
						end
					end;
					if self.Callbacks.partToToolsToRenderCallback then
						local tools = self.Callbacks.partToToolsToRenderCallback(part)
						if tools then
							self._cache.tools[part] = tools
						end
					end
				end
			end
		end
	end;
	function ESP:_OnRender()
		if not self.Config.Enabled then
			return
		end;
		self:_UpdateCache()
		for _, part in ipairs(self._cache.parts) do
			if part and part.Parent then
				local partPosition = self:GetPartPosition(part)
				local screenPos, distance = self:WorldToScreen(partPosition)
				if screenPos and distance <= self.Config.MaxDistance then
					local boxWidth, boxHeight = self:GetPartBoxSize(part)
					local partName = part.Name;
					if part:IsA("Model") and part:FindFirstChild("Humanoid") then
						local humanoid = part:FindFirstChild("Humanoid")
						if humanoid.DisplayName and humanoid.DisplayName ~= "" then
							partName = humanoid.DisplayName
						end
					end;
					self:DrawBox(part, screenPos, boxWidth, boxHeight, distance)
					self:DrawHealthBar(part, screenPos, boxWidth, boxHeight)
					self:DrawNameAndDistance(part, screenPos, partName, distance)
					self:DrawTools(part, screenPos, boxWidth, boxHeight)
				end
			end
		end;
		for _, obj in ipairs(self._activeObjects) do
			if obj.type == "circle" and obj.position then
				local screenPos = self:WorldToScreen(obj.position)
				if screenPos then
					DrawingImmediate.Circle(screenPos, obj.radius, obj.color, 1, 32, 2)
				end
			elseif obj.type == "line" and obj.from and obj.to then
				local fromScreen = self:WorldToScreen(obj.from)
				local toScreen = self:WorldToScreen(obj.to)
				if fromScreen and toScreen then
					DrawingImmediate.Line(fromScreen, toScreen, obj.color, 1, obj.thickness or 1)
				end
			end
		end
	end;
	function ESP:SetGetPartsToRenderCallback(callback)
		self.Callbacks.getPartsToRenderCallback = callback
	end;
	function ESP:SetPartToHealthCallback(callback)
		self.Callbacks.partToHealthCallback = callback
	end;
	function ESP:SetPartToToolsToRenderCallback(callback)
		self.Callbacks.partToToolsToRenderCallback = callback
	end;
	function ESP:ClearCallbacks()
		self.Callbacks.getPartsToRenderCallback = nil;
		self.Callbacks.partToHealthCallback = nil;
		self.Callbacks.partToToolsToRenderCallback = nil
	end;
	function ESP:AddObject(object)
		self._activeObjects[#self._activeObjects + 1] = object;
		return object
	end;
	function ESP:RemoveObject(object)
		for i, obj in ipairs(self._activeObjects) do
			if obj == object then
				table.remove(self._activeObjects, i)
				break
			end
		end
	end;
	function ESP:ClearObjects()
		self._activeObjects = {}
	end;
	function ESP:SetConfig(newConfig)
		for k, v in pairs(newConfig) do
			self.Config[k] = v
		end
	end;
	function ESP:Toggle()
		self.Config.Enabled = not self.Config.Enabled;
		return self.Config.Enabled
	end;
	function ESP:Init()
		if self._signal then
			self:_Cleanup()
		end;
		self._signal = DrawingImmediate.GetPaint(self.Config.ZIndex)
		local connection = self._signal:Connect(function()
			self:_OnRender()
		end)
		self._connections[#self._connections + 1] = connection
	end;
	function ESP:_Cleanup()
		for _, conn in ipairs(self._connections) do
			conn:Disconnect()
		end;
		self._connections = {}
		self._signal = nil
	end;
	function ESP:Destroy()
		self:_Cleanup()
		self._activeObjects = {}
		self:ClearCallbacks()
		self._cache = {
			parts = {},
			health = {},
			tools = {},
			lastUpdate = 0,
			updateInterval = 0.1
		}
	end;
	function ESP:ForceUpdate()
		self._cache.lastUpdate = 0;
		self:_UpdateCache()
	end;
	return ESP
else
	local ESP = {
		Config = {
			ZIndex = 2,
			Enabled = true,
			ShowHealthBars = true,
			ShowNames = true,
			ShowBoxes = true,
			ShowDistance = true,
			ShowTools = true,
			BoxThickness = 1,
			NameFont = 1,
			FontSize = 12,
			NameColor = Color3.new(1, 1, 1),
			BoxColor = Color3.new(1, 1, 1),
			HealthBarWidth = 2,
			HealthBarHeight = 10,
			MaxDistance = 100,
			ToolIconSize = 16
		},
		Callbacks = {
			getPartsToRenderCallback = nil,
			partToHealthCallback = nil,
			partToToolsToRenderCallback = nil
		},
		_activeObjects = {},
		_drawingObjects = {},
		_cache = {
			parts = {},
			health = {},
			tools = {},
			lastUpdate = 0,
			updateInterval = 0.1
		}
	}
	function ESP:WorldToScreen(worldPosition)
		local camera = workspace.CurrentCamera;
		if not camera then
			return nil
		end;
		local vector, onScreen = camera:WorldToViewportPoint(worldPosition)
		if onScreen and vector.Z > 0 then
			return Vector2.new(vector.X, vector.Y), vector.Z
		end;
		return nil, nil
	end;
	function ESP:GetHealthColor(currentHealth, maxHealth)
		if not currentHealth or not maxHealth or maxHealth <= 0 then
			return Color3.new(1, 1, 1)
		end;
		local percent = currentHealth / maxHealth;
		if percent > 0.7 then
			return Color3.new(0, 1, 0)
		elseif percent > 0.3 then
			return Color3.new(1, 1, 0)
		else
			return Color3.new(1, 0, 0)
		end
	end;
	function ESP:GetPartBoxSize(part)
		if not part then
			return 2, 2
		end;
		if part:IsA("Model") then
			local size = part:GetExtentsSize()
			return size.X * 2, size.Y * 2
		end;
		if part:IsA("BasePart") then
			local size = part.Size;
			return size.X, size.Y
		end;
		return 2, 2
	end;
	function ESP:GetPartPosition(part)
		if part:IsA("Model") then
			local primary = part.PrimaryPart;
			if primary then
				return primary.Position
			end;
			local total = Vector3.new(0, 0, 0)
			local count = 0;
			for _, child in ipairs(part:GetDescendants()) do
				if child:IsA("BasePart") then
					total = total + child.Position;
					count = count + 1
				end
			end;
			if count > 0 then
				return total / count
			end;
			return part:GetPivot().Position
		end;
		if part:IsA("BasePart") then
			return part.Position
		end;
		return Vector3.new(0, 0, 0)
	end;
	function ESP:_CreateDrawingObject(type, properties)
		local obj = Drawing.new(type)
		for k, v in pairs(properties) do
			obj[k] = v
		end;
		obj.Visible = true;
		obj.ZIndex = self.Config.ZIndex;
		table.insert(self._drawingObjects, obj)
		return obj
	end;
	function ESP:_UpdateDrawingObject(obj, properties)
		for k, v in pairs(properties) do
			obj[k] = v
		end
	end;
	function ESP:_ClearDrawingObjects()
		for _, obj in ipairs(self._drawingObjects) do
			obj:Remove()
		end;
		self._drawingObjects = {}
	end;
	function ESP:DrawHealthBar(part, screenPos, boxWidth, boxHeight)
		if not self.Config.ShowHealthBars then
			return
		end;
		if not self.Callbacks.partToHealthCallback then
			return
		end;
		local healthInfo = self.Callbacks.partToHealthCallback(part)
		if not healthInfo then
			return
		end;
		local currentHealth = healthInfo.currentHealth or healthInfo[1]
		local maxHealth = healthInfo.maxHealth or healthInfo[2]
		if not currentHealth or not maxHealth or maxHealth <= 0 then
			return
		end;
		local healthPercent = math.clamp(currentHealth / maxHealth, 0, 1)
		local barWidth = boxWidth * healthPercent;
		local barPos = Vector2.new(screenPos.X - (boxWidth / 2), screenPos.Y - boxHeight - self.Config.HealthBarHeight - 2)
		local bgBar = self:_CreateDrawingObject("Square", {
			Position = barPos,
			Size = Vector2.new(boxWidth, self.Config.HealthBarHeight),
			Color = Color3.new(0.3, 0.3, 0.3),
			Transparency = 0.2,
			Thickness = 1,
			Filled = true
		})
		if barWidth > 0 then
			local healthBar = self:_CreateDrawingObject("Square", {
				Position = barPos,
				Size = Vector2.new(barWidth, self.Config.HealthBarHeight),
				Color = self:GetHealthColor(currentHealth, maxHealth),
				Transparency = 0,
				Thickness = 1,
				Filled = true
			})
		end;
		local healthText = string.format("%.0f/%.0f", currentHealth, maxHealth)
		local textPos = Vector2.new(screenPos.X, barPos.Y - 2)
		local textObj = self:_CreateDrawingObject("Text", {
			Position = textPos,
			Text = healthText,
			Color = Color3.new(1, 1, 1),
			Size = self.Config.FontSize - 2,
			Center = true,
			Font = self.Config.NameFont,
			Transparency = 0
		})
		local outlineObj = self:_CreateDrawingObject("Text", {
			Position = Vector2.new(textPos.X + 1, textPos.Y + 1),
			Text = healthText,
			Color = Color3.new(0, 0, 0),
			Size = self.Config.FontSize - 2,
			Center = true,
			Font = self.Config.NameFont,
			Transparency = 0
		})
	end;
	function ESP:DrawTools(part, screenPos, boxWidth, boxHeight)
		if not self.Config.ShowTools then
			return
		end;
		if not self.Callbacks.partToToolsToRenderCallback then
			return
		end;
		local tools = self.Callbacks.partToToolsToRenderCallback(part)
		if not tools or #tools == 0 then
			return
		end;
		local startX = screenPos.X - (boxWidth / 2)
		local startY = screenPos.Y + boxHeight + 5;
		local iconSize = self.Config.ToolIconSize;
		local spacing = 5;
		for i, tool in ipairs(tools) do
			local toolPart = tool.toolPart or tool[1]
			local toolName = tool.name or tool[2] or "Unknown"
			if toolPart and toolPart:IsA("BasePart") then
				local iconPos = Vector2.new(startX + (i - 1) * (iconSize + spacing), startY)
				self:_CreateDrawingObject("Square", {
					Position = iconPos,
					Size = Vector2.new(iconSize, iconSize),
					Color = Color3.new(0.2, 0.2, 0.2),
					Transparency = 0.2,
					Thickness = 1,
					Filled = true
				})
				self:_CreateDrawingObject("Square", {
					Position = iconPos,
					Size = Vector2.new(iconSize, iconSize),
					Color = Color3.new(1, 1, 1),
					Transparency = 0.5,
					Thickness = 1,
					Filled = false
				})
				local textPos = Vector2.new(iconPos.X + iconSize / 2, iconPos.Y + iconSize + 2)
				self:_CreateDrawingObject("Text", {
					Position = textPos,
					Text = toolName,
					Color = Color3.new(1, 1, 1),
					Size = self.Config.FontSize - 2,
					Center = true,
					Font = self.Config.NameFont,
					Transparency = 0
				})
				local toolScreenPos = self:WorldToScreen(toolPart.Position)
				if toolScreenPos then
					self:_CreateDrawingObject("Line", {
						From = screenPos,
						To = toolScreenPos,
						Color = Color3.new(1, 1, 0),
						Transparency = 0.5,
						Thickness = 1
					})
				end
			end
		end
	end;
	function ESP:DrawNameAndDistance(part, screenPos, partName, distance)
		if not self.Config.ShowNames and not self.Config.ShowDistance then
			return
		end;
		local text = ""
		if self.Config.ShowNames then
			text = partName or "Unknown"
		end;
		if self.Config.ShowDistance and distance then
			local distText = string.format(" [%.0fm]", distance)
			text = text .. distText
		end;
		if text ~= "" then
			local textPos = Vector2.new(screenPos.X, screenPos.Y - 25)
			self:_CreateDrawingObject("Text", {
				Position = Vector2.new(textPos.X + 1, textPos.Y + 1),
				Text = text,
				Color = Color3.new(0, 0, 0),
				Size = self.Config.FontSize,
				Center = true,
				Font = self.Config.NameFont,
				Transparency = 0
			})
			self:_CreateDrawingObject("Text", {
				Position = textPos,
				Text = text,
				Color = self.Config.NameColor,
				Size = self.Config.FontSize,
				Center = true,
				Font = self.Config.NameFont,
				Transparency = 0
			})
		end
	end;
	function ESP:DrawBox(part, screenPos, boxWidth, boxHeight, distance)
		if not self.Config.ShowBoxes then
			return
		end;
		local topLeft = Vector2.new(screenPos.X - (boxWidth / 2), screenPos.Y - boxHeight)
		local boxColor = self.Config.BoxColor;
		if self.Config.ShowHealthBars and self.Callbacks.partToHealthCallback then
			local healthInfo = self.Callbacks.partToHealthCallback(part)
			if healthInfo then
				local currentHealth = healthInfo.currentHealth or healthInfo[1]
				local maxHealth = healthInfo.maxHealth or healthInfo[2]
				if currentHealth and maxHealth then
					boxColor = self:GetHealthColor(currentHealth, maxHealth)
				end
			end
		end;
		self:_CreateDrawingObject("Square", {
			Position = topLeft,
			Size = Vector2.new(boxWidth, boxHeight),
			Color = boxColor,
			Transparency = 0,
			Thickness = self.Config.BoxThickness,
			Filled = false
		})
		local accentSize = math.min(10, boxWidth * 0.2)
		local accentColor = Color3.new(1, 1, 1)
		self:_CreateDrawingObject("Line", {
			From = topLeft,
			To = Vector2.new(topLeft.X + accentSize, topLeft.Y),
			Color = accentColor,
			Transparency = 0.2,
			Thickness = 2
		})
		self:_CreateDrawingObject("Line", {
			From = topLeft,
			To = Vector2.new(topLeft.X, topLeft.Y + accentSize),
			Color = accentColor,
			Transparency = 0.2,
			Thickness = 2
		})
		local topRight = Vector2.new(topLeft.X + boxWidth, topLeft.Y)
		self:_CreateDrawingObject("Line", {
			From = Vector2.new(topRight.X - accentSize, topRight.Y),
			To = topRight,
			Color = accentColor,
			Transparency = 0.2,
			Thickness = 2
		})
		self:_CreateDrawingObject("Line", {
			From = topRight,
			To = Vector2.new(topRight.X, topRight.Y + accentSize),
			Color = accentColor,
			Transparency = 0.2,
			Thickness = 2
		})
		local bottomLeft = Vector2.new(topLeft.X, topLeft.Y + boxHeight)
		self:_CreateDrawingObject("Line", {
			From = bottomLeft,
			To = Vector2.new(bottomLeft.X + accentSize, bottomLeft.Y),
			Color = accentColor,
			Transparency = 0.2,
			Thickness = 2
		})
		self:_CreateDrawingObject("Line", {
			From = bottomLeft,
			To = Vector2.new(bottomLeft.X, bottomLeft.Y - accentSize),
			Color = accentColor,
			Transparency = 0.2,
			Thickness = 2
		})
		local bottomRight = Vector2.new(topLeft.X + boxWidth, topLeft.Y + boxHeight)
		self:_CreateDrawingObject("Line", {
			From = Vector2.new(bottomRight.X - accentSize, bottomRight.Y),
			To = bottomRight,
			Color = accentColor,
			Transparency = 0.2,
			Thickness = 2
		})
		self:_CreateDrawingObject("Line", {
			From = bottomRight,
			To = Vector2.new(bottomRight.X, bottomRight.Y - accentSize),
			Color = accentColor,
			Transparency = 0.2,
			Thickness = 2
		})
	end;
	function ESP:_UpdateCache()
		local currentTime = tick()
		if currentTime - self._cache.lastUpdate < self._cache.updateInterval then
			return
		end;
		self._cache.lastUpdate = currentTime;
		self._cache.parts = {}
		self._cache.health = {}
		self._cache.tools = {}
		if self.Callbacks.getPartsToRenderCallback then
			local parts = self.Callbacks.getPartsToRenderCallback()
			if parts then
				for i, part in ipairs(parts) do
					self._cache.parts[#self._cache.parts + 1] = part;
					if self.Callbacks.partToHealthCallback then
						local health = self.Callbacks.partToHealthCallback(part)
						if health then
							self._cache.health[part] = health
						end
					end;
					if self.Callbacks.partToToolsToRenderCallback then
						local tools = self.Callbacks.partToToolsToRenderCallback(part)
						if tools then
							self._cache.tools[part] = tools
						end
					end
				end
			end
		end
	end;
	function ESP:_OnRender()
		if not self.Config.Enabled then
			return
		end;
		self:_ClearDrawingObjects()
		self:_UpdateCache()
		for _, part in ipairs(self._cache.parts) do
			if part and part.Parent then
				local partPosition = self:GetPartPosition(part)
				local screenPos, distance = self:WorldToScreen(partPosition)
				if screenPos and distance <= self.Config.MaxDistance then
					local boxWidth, boxHeight = self:GetPartBoxSize(part)
					local partName = part.Name;
					if part:IsA("Model") and part:FindFirstChild("Humanoid") then
						local humanoid = part:FindFirstChild("Humanoid")
						if humanoid.DisplayName and humanoid.DisplayName ~= "" then
							partName = humanoid.DisplayName
						end
					end;
					self:DrawBox(part, screenPos, boxWidth, boxHeight, distance)
					self:DrawHealthBar(part, screenPos, boxWidth, boxHeight)
					self:DrawNameAndDistance(part, screenPos, partName, distance)
					self:DrawTools(part, screenPos, boxWidth, boxHeight)
				end
			end
		end;
		for _, obj in ipairs(self._activeObjects) do
			if obj.type == "circle" and obj.position then
				local screenPos = self:WorldToScreen(obj.position)
				if screenPos then
					self:_CreateDrawingObject("Circle", {
						Position = screenPos,
						Radius = obj.radius,
						Color = obj.color,
						Transparency = obj.transparency or 0,
						Thickness = obj.thickness or 2,
						Filled = obj.filled or false,
						NumSides = 32
					})
				end
			elseif obj.type == "line" and obj.from and obj.to then
				local fromScreen = self:WorldToScreen(obj.from)
				local toScreen = self:WorldToScreen(obj.to)
				if fromScreen and toScreen then
					self:_CreateDrawingObject("Line", {
						From = fromScreen,
						To = toScreen,
						Color = obj.color,
						Transparency = obj.transparency or 0,
						Thickness = obj.thickness or 1
					})
				end
			end
		end
	end;
	function ESP:SetGetPartsToRenderCallback(callback)
		self.Callbacks.getPartsToRenderCallback = callback
	end;
	function ESP:SetPartToHealthCallback(callback)
		self.Callbacks.partToHealthCallback = callback
	end;
	function ESP:SetPartToToolsToRenderCallback(callback)
		self.Callbacks.partToToolsToRenderCallback = callback
	end;
	function ESP:ClearCallbacks()
		self.Callbacks.getPartsToRenderCallback = nil;
		self.Callbacks.partToHealthCallback = nil;
		self.Callbacks.partToToolsToRenderCallback = nil
	end;
	function ESP:AddObject(object)
		self._activeObjects[#self._activeObjects + 1] = object;
		return object
	end;
	function ESP:RemoveObject(object)
		for i, obj in ipairs(self._activeObjects) do
			if obj == object then
				table.remove(self._activeObjects, i)
				break
			end
		end
	end;
	function ESP:ClearObjects()
		self._activeObjects = {}
	end;
	function ESP:SetConfig(newConfig)
		for k, v in pairs(newConfig) do
			self.Config[k] = v
		end
	end;
	function ESP:Toggle()
		self.Config.Enabled = not self.Config.Enabled;
		return self.Config.Enabled
	end;
	function ESP:Init()
		if self._renderConnection then
			self:_Cleanup()
		end;
		self._renderConnection = game:GetService("RunService").RenderStepped:Connect(function()
			self:_OnRender()
		end)
	end;
	function ESP:_Cleanup()
		if self._renderConnection then
			self._renderConnection:Disconnect()
			self._renderConnection = nil
		end;
		self:_ClearDrawingObjects()
	end;
	function ESP:Destroy()
		self:_Cleanup()
		self._activeObjects = {}
		self:ClearCallbacks()
		self._cache = {
			parts = {},
			health = {},
			tools = {},
			lastUpdate = 0,
			updateInterval = 0.1
		}
	end;
	function ESP:ForceUpdate()
		self._cache.lastUpdate = 0;
		self:_UpdateCache()
	end;
	return ESP
end
