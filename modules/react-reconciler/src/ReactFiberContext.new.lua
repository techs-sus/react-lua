-- upstream: https://github.com/facebook/react/blob/17f582e0453b808860be59ed3437c6a426ae52de/packages/react-reconciler/src/ReactFiberContext.new.js
--[[*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow
]]
--!nolint LocalShadowPedantic

local Workspace = script.Parent.Parent
local Packages = Workspace.Parent.Packages
local LuauPolyfill = require(Packages.LuauPolyfill)
local Object = LuauPolyfill.Object

local Cryo = require(Packages.Cryo)

-- ROBLOX: use patched console from shared
local console = require(Workspace.Shared.console)

local ReactInternalTypes = require(script.Parent.ReactInternalTypes)
type Fiber = ReactInternalTypes.Fiber;
local ReactFiberStack = require(script.Parent["ReactFiberStack.new"])
type StackCursor<T> = ReactFiberStack.StackCursor<T>;

local isFiberMounted = require(script.Parent.ReactFiberTreeReflection).isFiberMounted
local disableLegacyContext = require(Workspace.Shared.ReactFeatureFlags).disableLegacyContext
local ReactWorkTags = require(script.Parent.ReactWorkTags)
local ClassComponent = ReactWorkTags.ClassComponent
local HostRoot = ReactWorkTags.HostRoot
local getComponentName = require(Workspace.Shared.getComponentName)
local invariant = require(Workspace.Shared.invariant)
local checkPropTypes = require(Workspace.Shared.checkPropTypes)

local createCursor = ReactFiberStack.createCursor
local push = ReactFiberStack.push
local pop = ReactFiberStack.pop

local warnedAboutMissingGetChildContext

if _G.__DEV__ then
	warnedAboutMissingGetChildContext = {}
end

local emptyContextObject = {}
if _G.__DEV__ then
	Object.freeze(emptyContextObject)
end

-- deviation: Common types
type Object = { [any]: any };

-- A cursor to the current merged context object on the stack.
local contextStackCursor: StackCursor<Object> = createCursor(
	emptyContextObject
)
-- A cursor to a boolean indicating whether the context has changed.
local didPerformWorkStackCursor: StackCursor<boolean> = createCursor(false)
-- Keep track of the previous context object that was on the stack.
-- We use this to get access to the parent context after we have already
-- pushed the next context provider, and now need to merge their contexts.
local previousContext: Object = emptyContextObject

-- deviation: Pre-declare function
local isContextProvider

-- deviation: FIXME: `Component: Function` - lock down component type def
local function getUnmaskedContext(
	workInProgress: Fiber,
	Component: any,
	didPushOwnContextIfProvider: boolean
): Object
	if disableLegacyContext then
		return emptyContextObject
	else
		if didPushOwnContextIfProvider and isContextProvider(Component) then
			-- If the fiber is a context provider itself, when we read its context
			-- we may have already pushed its own child context on the stack. A context
			-- provider should not "see" its own child context. Therefore we read the
			-- previous (parent) context instead for a context provider.
			return previousContext
		end
		return contextStackCursor.current
	end
end

local function cacheContext(
	workInProgress: Fiber,
	unmaskedContext: Object,
	maskedContext: Object
)
	if disableLegacyContext then
		return
	else
		local instance = workInProgress.stateNode
		instance.__reactInternalMemoizedUnmaskedChildContext = unmaskedContext
		instance.__reactInternalMemoizedMaskedChildContext = maskedContext
	end
end

local function getMaskedContext(
	workInProgress: Fiber,
	unmaskedContext: Object
): Object
	if disableLegacyContext then
		return emptyContextObject
	else
		local type = workInProgress.type
		-- deviation: For function components, we can't support `contextTypes`;
		-- instead, just return unmaskedContext
		if typeof(type) == "function" then
			return unmaskedContext
		end

		local contextTypes = type.contextTypes
		if not contextTypes then
			return emptyContextObject
		end

		-- Avoid recreating masked context unless unmasked context has changed.
		-- Failing to do this will result in unnecessary calls to componentWillReceiveProps.
		-- This may trigger infinite loops if componentWillReceiveProps calls setState.
		local instance = workInProgress.stateNode
		if
			instance and
			instance.__reactInternalMemoizedUnmaskedChildContext == unmaskedContext
		then
			return instance.__reactInternalMemoizedMaskedChildContext
		end

		local context = {}
		for key, _ in pairs(contextTypes) do
			context[key] = unmaskedContext[key]
		end

		if _G.__DEV__ then
			local name = getComponentName(type) or "Unknown"
			checkPropTypes(contextTypes, context, "context", name)
		end

		-- Cache unmasked context so we can avoid recreating masked context unless necessary.
		-- Context is created before the class component is instantiated so check for instance.
		if instance then
			cacheContext(workInProgress, unmaskedContext, context)
		end

		return context
	end
end

local function hasContextChanged(): boolean
	if disableLegacyContext then
		return false
	else
		return didPerformWorkStackCursor.current
	end
end

-- deviation: `type: Function` - lock down component type def
isContextProvider = function(type): boolean
	if disableLegacyContext then
		return false
	else
		-- deviation: context types only valid for class components
		if typeof(type) == "function" then
			return false
		end
		local childContextTypes = type.childContextTypes
		return childContextTypes ~= nil
	end
end

local function popContext(fiber: Fiber)
	if disableLegacyContext then
		return
	else
		pop(didPerformWorkStackCursor, fiber)
		pop(contextStackCursor, fiber)
	end
end

local function popTopLevelContextObject(fiber: Fiber)
	if disableLegacyContext then
		return
	else
		pop(didPerformWorkStackCursor, fiber)
		pop(contextStackCursor, fiber)
	end
end

local function pushTopLevelContextObject(
	fiber: Fiber,
	context: Object,
	didChange: boolean
)
	if disableLegacyContext then
		return
	else
		invariant(
			contextStackCursor.current == emptyContextObject,
			"Unexpected context found on stack. " ..
				"This error is likely caused by a bug in React. Please file an issue."
		)

		push(contextStackCursor, context, fiber)
		push(didPerformWorkStackCursor, didChange, fiber)
	end
end

local function processChildContext(
	fiber: Fiber,
	type: any,
	parentContext: Object
): Object
	if disableLegacyContext then
		return parentContext
	else
		local instance = fiber.stateNode
		local childContextTypes = type.childContextTypes

		-- TODO (bvaughn) Replace this behavior with an invariant() in the future.
		-- It has only been added in Fiber to match the (unintentional) behavior in Stack.
		if typeof(instance.getChildContext) ~= "function" then
			if _G.__DEV__ then
				local componentName = getComponentName(type) or "Unknown"

				if not warnedAboutMissingGetChildContext[componentName] then
					warnedAboutMissingGetChildContext[componentName] = true
					console.error(
						"%s.childContextTypes is specified but there is no getChildContext() method " ..
							"on the instance. You can either define getChildContext() on %s or remove " ..
							"childContextTypes from it.",
						componentName,
						componentName
					)
				end
			end
			return parentContext
		end

		local childContext = instance.getChildContext()
		for contextKey, _ in pairs(childContext) do
			invariant(
				childContextTypes[contextKey] ~= nil,
				"%s.getChildContext(): key \"%s\" is not defined in childContextTypes.",
				getComponentName(type) or "Unknown",
				contextKey
			)
		end
		if _G.__DEV__ then
			local name = getComponentName(type) or "Unknown"
			checkPropTypes(childContextTypes, childContext, "child context", name)
		end

		return Cryo.Dictionary.join(parentContext, childContext)
	end
end

local function pushContextProvider(workInProgress: Fiber): boolean
	if disableLegacyContext then
		return false
	else
		local instance = workInProgress.stateNode
		-- We push the context as early as possible to ensure stack integrity.
		-- If the instance does not exist yet, we will push nil at first,
		-- and replace it on the stack later when invalidating the context.
		local memoizedMergedChildContext =
			(instance and instance.__reactInternalMemoizedMergedChildContext) or
			emptyContextObject

		-- Remember the parent context so we can merge with it later.
		-- Inherit the parent's did-perform-work value to avoid inadvertently blocking updates.
		previousContext = contextStackCursor.current
		push(contextStackCursor, memoizedMergedChildContext, workInProgress)
		push(
			didPerformWorkStackCursor,
			didPerformWorkStackCursor.current,
			workInProgress
		)

		return true
	end
end

local function invalidateContextProvider(
	workInProgress: Fiber,
	type: any,
	didChange: boolean
)
	if disableLegacyContext then
		return
	else
		local instance = workInProgress.stateNode
		invariant(
			instance,
			"Expected to have an instance by this point. " ..
				"This error is likely caused by a bug in React. Please file an issue."
		)

		if didChange then
			-- Merge parent and own context.
			-- Skip this if we're not updating due to sCU.
			-- This avoids unnecessarily recomputing memoized values.
			local mergedContext = processChildContext(
				workInProgress,
				type,
				previousContext
			)
			instance.__reactInternalMemoizedMergedChildContext = mergedContext

			-- Replace the old (or empty) context with the new one.
			-- It is important to unwind the context in the reverse order.
			pop(didPerformWorkStackCursor, workInProgress)
			pop(contextStackCursor, workInProgress)
			-- Now push the new context and mark that it has changed.
			push(contextStackCursor, mergedContext, workInProgress)
			push(didPerformWorkStackCursor, didChange, workInProgress)
		else
			pop(didPerformWorkStackCursor, workInProgress)
			push(didPerformWorkStackCursor, didChange, workInProgress)
		end
	end
end

local function findCurrentUnmaskedContext(fiber: Fiber): Object
	if disableLegacyContext then
		return emptyContextObject
	else
		-- Currently this is only used with renderSubtreeIntoContainer; not sure if it
		-- makes sense elsewhere
		invariant(
			isFiberMounted(fiber) and fiber.tag == ClassComponent,
			"Expected subtree parent to be a mounted class component. " ..
				"This error is likely caused by a bug in React. Please file an issue."
		)

		local node = fiber
		repeat
			if node.tag == HostRoot then
				return node.stateNode.context
			elseif node.tag == ClassComponent then
				local Component = node.type
				if isContextProvider(Component) then
					return node.stateNode.__reactInternalMemoizedMergedChildContext
				end
			end

			node = node.return_
		until node == nil
		invariant(
			false,
			"Found unexpected detached subtree parent. " ..
				"This error is likely caused by a bug in React. Please file an issue."
		)
	end

	-- deviation: invariant not recognized as error, so we return something here
	return {}
end

return {
	emptyContextObject = emptyContextObject,
	getUnmaskedContext = getUnmaskedContext,
	cacheContext = cacheContext,
	getMaskedContext = getMaskedContext,
	hasContextChanged = hasContextChanged,
	popContext = popContext,
	popTopLevelContextObject = popTopLevelContextObject,
	pushTopLevelContextObject = pushTopLevelContextObject,
	processChildContext = processChildContext,
	isContextProvider = isContextProvider,
	pushContextProvider = pushContextProvider,
	invalidateContextProvider = invalidateContextProvider,
	findCurrentUnmaskedContext = findCurrentUnmaskedContext,
}
