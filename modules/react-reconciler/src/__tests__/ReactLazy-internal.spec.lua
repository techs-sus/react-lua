-- local PropTypes
local React
local ReactTestRenderer
local Scheduler
local ReactFeatureFlags
local Suspense
local lazy
local RobloxJest
local Workspace = script.Parent.Parent.Parent
local Packages = Workspace.Parent

-- local Promise = require(Packages.Promise)
local LuauPolyfill = require(Packages.LuauPolyfill)
local Error = LuauPolyfill.Error

-- local setTimeout = LuauPolyfill.setTimeout

-- local function normalizeCodeLocInfo(str)
--     return str and str.replace(function(m, name)
--         return'\n    in ' .. name .. ' (at **)'
--     end)
-- end

return function()
    describe('ReactLazy', function()
        RobloxJest = require(Workspace.RobloxJest)
        local jestExpect = require(Packages.Dev.JestRoblox).Globals.expect

        beforeEach(function()
            RobloxJest.resetModules()
            -- deviation: In react, jest _always_ mocks Scheduler -> unstable_mock;
            -- in our case, we need to do it anywhere we want to use the scheduler,
            -- directly or indirectly, until we have some form of bundling logic
            RobloxJest.mock(Workspace.Scheduler, function()
                return require(Workspace.Scheduler.unstable_mock)
            end)
            -- deviation: upstream has jest.mock return a function via
            -- scripts/setupHostConfigs.js, but it's easier for us to do it here
            RobloxJest.mock(Workspace.ReactReconciler.ReactFiberHostConfig, function()
                return require(Workspace.ReactTestRenderer.ReactTestHostConfig)
            end)

            ReactFeatureFlags = require(Workspace.Shared.ReactFeatureFlags)
            ReactFeatureFlags.replayFailedUnitOfWorkWithInvokeGuardedCallback = false
            -- PropTypes = require('prop-types');
            React = require(Workspace.React)
            Suspense = React.Suspense
            lazy = React.lazy
            ReactTestRenderer = require(Workspace.ReactTestRenderer)
            Scheduler = require(Workspace.Scheduler)
        end)

        -- local verifyInnerPropTypesAreChecked = _async(function(Add)
        --     local LazyAdd = lazy(function()
        --         return fakeImport(Add)
        --     end)

        --     expect(function()
        --         LazyAdd.propTypes = {}
        --     end).toErrorDev('React.lazy(...): It is not supported to assign `propTypes` to ' + 'a lazy component import. Either specify them where the component ' + 'is defined, or create a wrapping component around it.', {withoutStack = true})

        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyAdd, {
        --         inner = '2',
        --         outer = '2',
        --     })), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('22')

        --     return _await(Promise.resolve(), function()
        --         expect(function()
        --             Scheduler.unstable_flushAll()
        --         end).toErrorDev({
        --             'Invalid prop `inner` of type `string` supplied to `Add`, expected `number`.',
        --         })
        --         expect(root).toMatchRenderedOutput('22')
        --         expect(function()
        --             root.update(React.createElement(Suspense, {
        --                 fallback = React.createElement(Text, {
        --                     text = 'Loading...',
        --                 }),
        --             }, React.createElement(LazyAdd, {
        --                 inner = false,
        --                 outer = false,
        --             })))
        --             expect(Scheduler).toFlushWithoutYielding()
        --         end).toErrorDev('Invalid prop `inner` of type `boolean` supplied to `Add`, expected `number`.')
        --         expect(root).toMatchRenderedOutput('0')
        --     end)
        -- end)

        local fakeImport = function(result)
            return {
                then_ = function(resolve)
                    return resolve({default = result})
                end
            }
        end

        local function Text(props)
            Scheduler.unstable_yieldValue(props.text)

            return props.text
        end

        -- local delay = function(ms)
        --     return Promise.new(function(resolve)
        --         return setTimeout(function()
        --             return resolve()
        --         end, ms)
        --     end)
        -- end

        -- xit('suspends until module has loaded', function()
        --     local LazyText = lazy(function()
        --         return fakeImport(Text)
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyText, {
        --         text = 'Hi',
        --     })), {unstable_isConcurrent = true})

        --     jestExpect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })

        --     jestExpect(root).never.toMatchRenderedOutput('Hi')

        --     Promise.resolve():await()

        --     jestExpect(Scheduler).toFlushAndYield({
        --         'Hi',
        --     })
        --     jestExpect(root).toMatchRenderedOutput('Hi')

        --     -- Should not suspend on update
        --     root.update(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyText, {
        --         text = 'Hi again',
        --     })))
        --     jestExpect(Scheduler).toFlushAndYield({
        --         'Hi again',
        --     })
        --     jestExpect(root).toMatchRenderedOutput('Hi again')

        -- end)
        it('can resolve synchronously without suspending', function()
            local LazyText = lazy(function()
                return {
                    then_ = function(cb)
                        cb({default = Text})
                    end,
                }
            end)
            local root = ReactTestRenderer.create(React.createElement(Suspense, {
                fallback = React.createElement(Text, {
                    text = 'Loading...',
                }),
            }, React.createElement(LazyText, {
                text = 'Hi',
            })))

            jestExpect(Scheduler).toHaveYielded({
                'Hi',
            })
            jestExpect(root).toMatchRenderedOutput('Hi')
        end)
        it('can reject synchronously without suspending', function()
            local LazyText = lazy(function()
                return {
                    then_ = function(resolve, reject)
                        reject(Error('oh no'))
                    end,
                }
            end)
            local ErrorBoundary = React.Component:extend("ErrorBoundary")

            function ErrorBoundary:init()
                self.state = {}
            end
            function ErrorBoundary.getDerivedStateFromError(error_)
                return {
                    message = error_.message,
                }
            end
            function ErrorBoundary:render()
                    if self.state.message then
                        return('Error: %s'):format(self.state.message)
                    end
                    return self.props.children
            end

            local root = ReactTestRenderer.create(React.createElement(ErrorBoundary, nil, React.createElement(Suspense, {
                fallback = React.createElement(Text, {
                    text = 'Loading...',
                }),
            }, React.createElement(LazyText, {
                text = 'Hi',
            }))))

            jestExpect(Scheduler).toHaveYielded({})
            jestExpect(root).toMatchRenderedOutput('Error: oh no')
        end)
        -- xit('multiple lazy components', function()
        --     local function Foo()
        --         return React.createElement(Text, {
        --             text = 'Foo',
        --         })
        --     end
        --     local function Bar()
        --         return React.createElement(Text, {
        --             text = 'Bar',
        --         })
        --     end

        --     local promiseForFoo = delay(100):andThen(function()
        --         return fakeImport(Foo)
        --     end)
        --     local promiseForBar = delay(500):andThen(function()
        --         return fakeImport(Bar)
        --     end)
        --     local LazyFoo = lazy(function()
        --         return promiseForFoo
        --     end)
        --     local LazyBar = lazy(function()
        --         return promiseForBar
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyFoo, nil), React.createElement(LazyBar, nil)), {unstable_isConcurrent = true})

        --     jestExpect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     jestExpect(root).never.toMatchRenderedOutput('FooBar')
        --     RobloxJest.advanceTimersByTime(100)

        --     promiseForFoo:await()
        --     RobloxJest.Expect(Scheduler).toFlushAndYield({
        --         'Foo',
        --     })
        --     jestExpect(root).never.toMatchRenderedOutput('FooBar')
        --     RobloxJest.advanceTimersByTime(500)

        --     promiseForBar:await()

        --     jestExpect(Scheduler).toFlushAndYield({
        --         'Foo',
        --         'Bar',
        --     })
        --     jestExpect(root).toMatchRenderedOutput('FooBar')
        -- end)
        -- it('does not support arbitrary promises, only module objects', _async(function()
        --     spyOnDev(console, 'error')

        --     local LazyText = lazy(function()
        --         return _await(Text)
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyText, {
        --         text = 'Hi',
        --     })), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('Hi')

        --     return _await(Promise.resolve(), function()
        --         if __DEV__ then
        --             expect(console.error).toHaveBeenCalledTimes(1)
        --             expect(console.error.calls.argsFor(0)[0]).toContain('Expected the result of a dynamic import() call')
        --         end

        --         expect(Scheduler).toFlushAndThrow('Element type is invalid')
        --     end)
        -- end))
        -- xit('throws if promise rejects', function()
        --     local LazyText = lazy(Promise.promisify(function()
        --         error(Error('Bad network'))
        --     end))
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyText, {
        --         text = 'Hi',
        --     })), {unstable_isConcurrent = true})

        --     jestExpect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     jestExpect(root).never.toMatchRenderedOutput('Hi')

        --     local _, _ = pcall(function()
        --         Promise.resolve():await()
        --     end)

        --     jestExpect(Scheduler).toFlushAndThrow('Bad network')

        -- end)
        -- xit('mount and reorder', function()
        --     local Child = React.Component:extend("Child")

        --     function Child:componentDidMount()
        --         Scheduler.unstable_yieldValue('Did mount: ' .. self.props.label)
        --     end
        --     function Child:componentDidUpdate()
        --         Scheduler.unstable_yieldValue('Did update: ' .. self.props.label)
        --     end
        --     function Child:render()
        --         return React.createElement(Text, {
        --             text = self.props.label,
        --         })
        --     end

        --     local LazyChildA = lazy(function()
        --         return fakeImport(Child)
        --     end)
        --     local LazyChildB = lazy(function()
        --         return fakeImport(Child)
        --     end)

        --     local function Parent(props)
        --         local children
        --         if props.swap then
        --             children = {
        --                 React.createElement(LazyChildB, {
        --                     key = 'B',
        --                     label = 'B',
        --                 }),
        --                 React.createElement(LazyChildA, {
        --                     key = 'A',
        --                     label = 'A',
        --                 }),
        --             }
        --         else
        --             children = {
        --                 React.createElement(LazyChildA, {
        --                     key = 'A',
        --                     label = 'A',
        --                 }),
        --                 React.createElement(LazyChildB, {
        --                     key = 'B',
        --                     label = 'B',
        --                 }),
        --             }
        --         end
        --         return React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, children)
        --     end

        --     local root = ReactTestRenderer.create(React.createElement(Parent, {swap = false}), {unstable_isConcurrent = true})


        --     jestExpect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     jestExpect(root).never.toMatchRenderedOutput('AB')

        --     LazyChildA:await()
        --     LazyChildB:await()

        --     jestExpect(Scheduler).toFlushAndYield({
        --         'A',
        --         'B',
        --         'Did mount: A',
        --         'Did mount: B',
        --     })
        --     jestExpect(root).toMatchRenderedOutput('AB')

        --     -- Swap the potsition of A and B
        --     root.update(React.createElement(Parent, {swap = true}))
        --     jestExpect(Scheduler).toFlushAndYield({
        --         'B',
        --         'A',
        --         'Did update: B',
        --         'Did update: A',
        --     })
        --     jestExpect(root).toMatchRenderedOutput('BA')
        -- end)
        -- it('resolves defaultProps, on mount and update', _async(function()
        --     local function T(props)
        --         return React.createElement(Text, props)
        --     end

        --     T.defaultProps = {
        --         text = 'Hi',
        --     }

        --     local LazyText = lazy(function()
        --         return fakeImport(T)
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyText, nil)), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('Hi')

        --     return _await(Promise.resolve(), function()
        --         expect(Scheduler).toFlushAndYield({
        --             'Hi',
        --         })
        --         expect(root).toMatchRenderedOutput('Hi')

        --         T.defaultProps = {
        --             text = 'Hi again',
        --         }

        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyText, nil)))
        --         expect(Scheduler).toFlushAndYield({
        --             'Hi again',
        --         })
        --         expect(root).toMatchRenderedOutput('Hi again')
        --     end)
        -- end))
        -- it('resolves defaultProps without breaking memoization', _async(function()
        --     local function LazyImpl(props)
        --         Scheduler.unstable_yieldValue('Lazy')

        --         return React.createElement(React.Fragment, nil, React.createElement(Text, {
        --             text = props.siblingText,
        --         }), props.children)
        --     end

        --     LazyImpl.defaultProps = {
        --         siblingText = 'Sibling',
        --     }

        --     local Lazy = lazy(function()
        --         return fakeImport(LazyImpl)
        --     end)
        --     local Stateful = {}
        --     local StatefulMetatable = {__index = Stateful}

        --     function Stateful.new()
        --         local self = setmetatable({}, StatefulMetatable)
        --         local _temp2

        --         return
        --     end
        --     function Stateful:render()
        --         return React.createElement(Text, {
        --             text = self.state.text,
        --         })
        --     end

        --     local stateful = React.createRef(nil)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(Lazy, nil, React.createElement(Stateful, {ref = stateful}))), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('SiblingA')

        --     return _await(Promise.resolve(), function()
        --         expect(Scheduler).toFlushAndYield({
        --             'Lazy',
        --             'Sibling',
        --             'A',
        --         })
        --         expect(root).toMatchRenderedOutput('SiblingA')
        --         stateful.current.setState({
        --             text = 'B',
        --         })
        --         expect(Scheduler).toFlushAndYield({
        --             'B',
        --         })
        --         expect(root).toMatchRenderedOutput('SiblingB')
        --     end)
        -- end))
        -- it('resolves defaultProps without breaking bailout due to unchanged props and state, #17151', _async(function()
        --     local LazyImpl = {}
        --     local LazyImplMetatable = {__index = LazyImpl}

        --     function LazyImpl:render()
        --         local text = ('%s: %s'):format(self.props.label, self.props.value)

        --         return React.createElement(Text, {text = text})
        --     end

        --     LazyImpl.defaultProps = {value = 0}

        --     local Lazy = lazy(function()
        --         return fakeImport(LazyImpl)
        --     end)
        --     local instance1 = React.createRef(nil)
        --     local instance2 = React.createRef(nil)
        --     local root = ReactTestRenderer.create(React.createElement(React.Fragment, nil, React.createElement(LazyImpl, {
        --         ref = instance1,
        --         label = 'Not lazy',
        --     }), React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(Lazy, {
        --         ref = instance2,
        --         label = 'Lazy',
        --     }))), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Not lazy: 0',
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('Not lazy: 0Lazy: 0')

        --     return _await(Promise.resolve(), function()
        --         expect(Scheduler).toFlushAndYield({
        --             'Lazy: 0',
        --         })
        --         expect(root).toMatchRenderedOutput('Not lazy: 0Lazy: 0')
        --         instance1.current.setState(nil)
        --         expect(Scheduler).toFlushAndYield({})
        --         expect(root).toMatchRenderedOutput('Not lazy: 0Lazy: 0')
        --         instance2.current.setState(nil)
        --         expect(Scheduler).toFlushAndYield({})
        --         expect(root).toMatchRenderedOutput('Not lazy: 0Lazy: 0')
        --     end)
        -- end))
        -- it('resolves defaultProps without breaking bailout in PureComponent, #17151', _async(function()
        --     local LazyImpl = {}
        --     local LazyImplMetatable = {__index = LazyImpl}

        --     function LazyImpl.new()
        --         local self = setmetatable({}, LazyImplMetatable)
        --         local _temp3

        --         return
        --     end
        --     function LazyImpl:render()
        --         local text = ('%s: %s'):format(self.props.label, self.props.value)

        --         return React.createElement(Text, {text = text})
        --     end

        --     LazyImpl.defaultProps = {value = 0}

        --     local Lazy = lazy(function()
        --         return fakeImport(LazyImpl)
        --     end)
        --     local instance1 = React.createRef(nil)
        --     local instance2 = React.createRef(nil)
        --     local root = ReactTestRenderer.create(React.createElement(React.Fragment, nil, React.createElement(LazyImpl, {
        --         ref = instance1,
        --         label = 'Not lazy',
        --     }), React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(Lazy, {
        --         ref = instance2,
        --         label = 'Lazy',
        --     }))), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Not lazy: 0',
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('Not lazy: 0Lazy: 0')

        --     return _await(Promise.resolve(), function()
        --         expect(Scheduler).toFlushAndYield({
        --             'Lazy: 0',
        --         })
        --         expect(root).toMatchRenderedOutput('Not lazy: 0Lazy: 0')
        --         instance1.current.setState({})
        --         expect(Scheduler).toFlushAndYield({})
        --         expect(root).toMatchRenderedOutput('Not lazy: 0Lazy: 0')
        --         instance2.current.setState({})
        --         expect(Scheduler).toFlushAndYield({})
        --         expect(root).toMatchRenderedOutput('Not lazy: 0Lazy: 0')
        --     end)
        -- end))
        -- it('sets defaultProps for modern lifecycles', _async(function()
        --     local C = {}
        --     local CMetatable = {__index = C}

        --     function C.getDerivedStateFromProps(props)
        --         Scheduler.unstable_yieldValue(('getDerivedStateFromProps: %s'):format(props.text))

        --         return nil
        --     end
        --     function C.new(props)
        --         local self = setmetatable({}, CMetatable)

        --         self.state = {}

        --         Scheduler.unstable_yieldValue(('constructor: %s'):format(self.props.text))
        --     end
        --     function C:componentDidMount()
        --         Scheduler.unstable_yieldValue(('componentDidMount: %s'):format(self.props.text))
        --     end
        --     function C:componentDidUpdate(prevProps)
        --         Scheduler.unstable_yieldValue(('componentDidUpdate: %s -> %s'):format(prevProps.text, self.props.text))
        --     end
        --     function C:componentWillUnmount()
        --         Scheduler.unstable_yieldValue(('componentWillUnmount: %s'):format(self.props.text))
        --     end
        --     function C:shouldComponentUpdate(nextProps)
        --         Scheduler.unstable_yieldValue(('shouldComponentUpdate: %s -> %s'):format(self.props.text, nextProps.text))

        --         return true
        --     end
        --     function C:getSnapshotBeforeUpdate(prevProps)
        --         Scheduler.unstable_yieldValue(('getSnapshotBeforeUpdate: %s -> %s'):format(prevProps.text, self.props.text))

        --         return nil
        --     end
        --     function C:render()
        --         return React.createElement(Text, {
        --             text = self.props.text + self.props.num,
        --         })
        --     end

        --     C.defaultProps = {
        --         text = 'A',
        --     }

        --     local LazyClass = lazy(function()
        --         return fakeImport(C)
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyClass, {num = 1})), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('A1')

        --     return _await(Promise.resolve(), function()
        --         expect(Scheduler).toFlushAndYield({
        --             'constructor: A',
        --             'getDerivedStateFromProps: A',
        --             'A1',
        --             'componentDidMount: A',
        --         })
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyClass, {num = 2})))
        --         expect(Scheduler).toFlushAndYield({
        --             'getDerivedStateFromProps: A',
        --             'shouldComponentUpdate: A -> A',
        --             'A2',
        --             'getSnapshotBeforeUpdate: A -> A',
        --             'componentDidUpdate: A -> A',
        --         })
        --         expect(root).toMatchRenderedOutput('A2')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyClass, {num = 3})))
        --         expect(Scheduler).toFlushAndYield({
        --             'getDerivedStateFromProps: A',
        --             'shouldComponentUpdate: A -> A',
        --             'A3',
        --             'getSnapshotBeforeUpdate: A -> A',
        --             'componentDidUpdate: A -> A',
        --         })
        --         expect(root).toMatchRenderedOutput('A3')
        --     end)
        -- end))
        -- it('sets defaultProps for legacy lifecycles', _async(function()
        --     local C = {}
        --     local CMetatable = {__index = C}

        --     function C.new()
        --         local self = setmetatable({}, CMetatable)
        --         local _temp4

        --         return
        --     end
        --     function C:UNSAFE_componentWillMount()
        --         Scheduler.unstable_yieldValue(('UNSAFE_componentWillMount: %s'):format(self.props.text))
        --     end
        --     function C:UNSAFE_componentWillUpdate(nextProps)
        --         Scheduler.unstable_yieldValue(('UNSAFE_componentWillUpdate: %s -> %s'):format(self.props.text, nextProps.text))
        --     end
        --     function C:UNSAFE_componentWillReceiveProps(nextProps)
        --         Scheduler.unstable_yieldValue(('UNSAFE_componentWillReceiveProps: %s -> %s'):format(self.props.text, nextProps.text))
        --     end
        --     function C:render()
        --         return React.createElement(Text, {
        --             text = self.props.text + self.props.num,
        --         })
        --     end

        --     C.defaultProps = {
        --         text = 'A',
        --     }

        --     local LazyClass = lazy(function()
        --         return fakeImport(C)
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyClass, {num = 1})))

        --     expect(Scheduler).toHaveYielded({
        --         'Loading...',
        --     })
        --     expect(Scheduler).toFlushAndYield({})
        --     expect(root).toMatchRenderedOutput('Loading...')

        --     return _await(Promise.resolve(), function()
        --         expect(Scheduler).toHaveYielded({})
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyClass, {num = 2})))
        --         expect(Scheduler).toHaveYielded({
        --             'UNSAFE_componentWillMount: A',
        --             'A2',
        --         })
        --         expect(root).toMatchRenderedOutput('A2')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyClass, {num = 3})))
        --         expect(Scheduler).toHaveYielded({
        --             'UNSAFE_componentWillReceiveProps: A -> A',
        --             'UNSAFE_componentWillUpdate: A -> A',
        --             'A3',
        --         })
        --         expect(Scheduler).toFlushAndYield({})
        --         expect(root).toMatchRenderedOutput('A3')
        --     end)
        -- end))
        -- it('resolves defaultProps on the outer wrapper but warns', _async(function()
        --     local function T(props)
        --         Scheduler.unstable_yieldValue(props.inner + ' ' + props.outer)

        --         return props.inner + ' ' + props.outer
        --     end

        --     T.defaultProps = {
        --         inner = 'Hi',
        --     }

        --     local LazyText = lazy(function()
        --         return fakeImport(T)
        --     end)

        --     expect(function()
        --         LazyText.defaultProps = {
        --             outer = 'Bye',
        --         }
        --     end).toErrorDev('React.lazy(...): It is not supported to assign `defaultProps` to ' + 'a lazy component import. Either specify them where the component ' + 'is defined, or create a wrapping component around it.', {withoutStack = true})

        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyText, nil)), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('Hi Bye')

        --     return _await(Promise.resolve(), function()
        --         expect(Scheduler).toFlushAndYield({
        --             'Hi Bye',
        --         })
        --         expect(root).toMatchRenderedOutput('Hi Bye')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyText, {
        --             outer = 'World',
        --         })))
        --         expect(Scheduler).toFlushAndYield({
        --             'Hi World',
        --         })
        --         expect(root).toMatchRenderedOutput('Hi World')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyText, {
        --             inner = 'Friends',
        --         })))
        --         expect(Scheduler).toFlushAndYield({
        --             'Friends Bye',
        --         })
        --         expect(root).toMatchRenderedOutput('Friends Bye')
        --     end)
        -- end))
        -- it('throws with a useful error when wrapping invalid type with lazy()', _async(function()
        --     local BadLazy = lazy(function()
        --         return fakeImport(42)
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(BadLazy, nil)), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })

        --     return _await(Promise.resolve(), function()
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(BadLazy, nil)))
        --         expect(Scheduler).toFlushAndThrow('Element type is invalid. Received a promise that resolves to: 42. ' + 'Lazy element type must resolve to a class or function.')
        --     end)
        -- end))
        -- it('throws with a useful error when wrapping lazy() multiple times', _async(function()
        --     local Lazy1 = lazy(function()
        --         return fakeImport(Text)
        --     end)
        --     local Lazy2 = lazy(function()
        --         return fakeImport(Lazy1)
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(Lazy2, {
        --         text = 'Hello',
        --     })), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('Hello')

        --     return _await(Promise.resolve(), function()
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(Lazy2, {
        --             text = 'Hello',
        --         })))
        --         expect(Scheduler).toFlushAndThrow('Element type is invalid. Received a promise that resolves to: [object Object]. ' + 'Lazy element type must resolve to a class or function.' + (function(
        --         )
        --             if __DEV__ then
        --                 return' Did you wrap a component in React.lazy() more than once?'
        --             end

        --             return''
        --         end)())
        --     end)
        -- end))
        it('warns about defining propTypes on the outer wrapper', function()
            local LazyText = lazy(function()
                return fakeImport(Text)
            end)

            jestExpect(function()
                LazyText.propTypes = {
                    hello = function() end,
                }
            end).toErrorDev('React.lazy(...): It is not supported to assign `propTypes` to ' ..
                'a lazy component import. Either specify them where the component ' ..
                'is defined, or create a wrapping component around it.',
                {withoutStack = true}
            )
        end)
        -- it('respects propTypes on function component with defaultProps', _async(function()
        --     local function Add(props)
        --         expect(props.innerWithDefault).toBe(42)

        --         return props.inner + props.outer
        --     end

        --     Add.propTypes = {
        --         inner = PropTypes.number.isRequired,
        --         innerWithDefault = PropTypes.number.isRequired,
        --     }
        --     Add.defaultProps = {innerWithDefault = 42}

        --     return _awaitIgnored(verifyInnerPropTypesAreChecked(Add))
        -- end))
        -- it('respects propTypes on function component without defaultProps', _async(function()
        --     local function Add(props)
        --         return props.inner + props.outer
        --     end

        --     Add.propTypes = {
        --         inner = PropTypes.number.isRequired,
        --     }

        --     return _awaitIgnored(verifyInnerPropTypesAreChecked(Add))
        -- end))
        -- it('respects propTypes on class component with defaultProps', _async(function()
        --     local Add = {}
        --     local AddMetatable = {__index = Add}

        --     function Add:render()
        --         expect(self.props.innerWithDefault).toBe(42)

        --         return self.props.inner + self.props.outer
        --     end

        --     Add.propTypes = {
        --         inner = PropTypes.number.isRequired,
        --         innerWithDefault = PropTypes.number.isRequired,
        --     }
        --     Add.defaultProps = {innerWithDefault = 42}

        --     return _awaitIgnored(verifyInnerPropTypesAreChecked(Add))
        -- end))
        -- it('respects propTypes on class component without defaultProps', _async(function()
        --     local Add = {}
        --     local AddMetatable = {__index = Add}

        --     function Add:render()
        --         return self.props.inner + self.props.outer
        --     end

        --     Add.propTypes = {
        --         inner = PropTypes.number.isRequired,
        --     }

        --     return _awaitIgnored(verifyInnerPropTypesAreChecked(Add))
        -- end))
        -- it('respects propTypes on forwardRef component with defaultProps', _async(function()
        --     local Add = React.forwardRef(function(props, ref)
        --         expect(props.innerWithDefault).toBe(42)

        --         return props.inner + props.outer
        --     end)

        --     Add.displayName = 'Add'
        --     Add.propTypes = {
        --         inner = PropTypes.number.isRequired,
        --         innerWithDefault = PropTypes.number.isRequired,
        --     }
        --     Add.defaultProps = {innerWithDefault = 42}

        --     return _awaitIgnored(verifyInnerPropTypesAreChecked(Add))
        -- end))
        -- it('respects propTypes on forwardRef component without defaultProps', _async(function()
        --     local Add = React.forwardRef(function(props, ref)
        --         return props.inner + props.outer
        --     end)

        --     Add.displayName = 'Add'
        --     Add.propTypes = {
        --         inner = PropTypes.number.isRequired,
        --     }

        --     return _awaitIgnored(verifyInnerPropTypesAreChecked(Add))
        -- end))
        -- it('respects propTypes on outer memo component with defaultProps', _async(function()
        --     local Add = function(props)
        --         expect(props.innerWithDefault).toBe(42)

        --         return props.inner + props.outer
        --     end

        --     Add = React.memo(Add)
        --     Add.propTypes = {
        --         inner = PropTypes.number.isRequired,
        --         innerWithDefault = PropTypes.number.isRequired,
        --     }
        --     Add.defaultProps = {innerWithDefault = 42}

        --     return _awaitIgnored(verifyInnerPropTypesAreChecked(Add))
        -- end))
        -- it('respects propTypes on outer memo component without defaultProps', _async(function()
        --     local Add = function(props)
        --         return props.inner + props.outer
        --     end

        --     Add = React.memo(Add)
        --     Add.propTypes = {
        --         inner = PropTypes.number.isRequired,
        --     }

        --     return _awaitIgnored(verifyInnerPropTypesAreChecked(Add))
        -- end))
        -- it('respects propTypes on inner memo component with defaultProps', _async(function()
        --     local Add = function(props)
        --         expect(props.innerWithDefault).toBe(42)

        --         return props.inner + props.outer
        --     end

        --     Add.displayName = 'Add'
        --     Add.propTypes = {
        --         inner = PropTypes.number.isRequired,
        --         innerWithDefault = PropTypes.number.isRequired,
        --     }
        --     Add.defaultProps = {innerWithDefault = 42}

        --     return _awaitIgnored(verifyInnerPropTypesAreChecked(React.memo(Add)))
        -- end))
        -- it('respects propTypes on inner memo component without defaultProps', _async(function()
        --     local Add = function(props)
        --         return props.inner + props.outer
        --     end

        --     Add.displayName = 'Add'
        --     Add.propTypes = {
        --         inner = PropTypes.number.isRequired,
        --     }

        --     return _awaitIgnored(verifyInnerPropTypesAreChecked(React.memo(Add)))
        -- end))
        -- it('uses outer resolved props for validating propTypes on memo', _async(function()
        --     local T = function(props)
        --         return React.createElement(Text, {
        --             text = props.text,
        --         })
        --     end

        --     T.defaultProps = {
        --         text = 'Inner default text',
        --     }
        --     T = React.memo(T)
        --     T.propTypes = {
        --         text = PropTypes.string.isRequired,
        --     }

        --     local LazyText = lazy(function()
        --         return fakeImport(T)
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyText, nil)), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('Inner default text')

        --     return _await(Promise.resolve(), function()
        --         expect(function()
        --             expect(Scheduler).toFlushAndYield({
        --                 'Inner default text',
        --             })
        --         end).toErrorDev('The prop `text` is marked as required in `T`, but its value is `undefined`')
        --         expect(root).toMatchRenderedOutput('Inner default text')
        --         expect(function()
        --             root.update(React.createElement(Suspense, {
        --                 fallback = React.createElement(Text, {
        --                     text = 'Loading...',
        --                 }),
        --             }, React.createElement(LazyText, {text = nil})))
        --             expect(Scheduler).toFlushAndYield({nil})
        --         end).toErrorDev('The prop `text` is marked as required in `T`, but its value is `null`')
        --         expect(root).toMatchRenderedOutput(nil)
        --     end)
        -- end))

        -- ROBLOX FIXME:
        xit('includes lazy-loaded component in warning stack', function()
            local LazyFoo = lazy(function()
                Scheduler.unstable_yieldValue('Started loading')

                local Foo = function(props)
                    return React.createElement('div', nil, {
                        React.createElement(Text, {
                            text = 'A',
                        }),
                        React.createElement(Text, {
                            text = 'B',
                        }),
                    })
                end

                return fakeImport(Foo)
            end)
            local root = ReactTestRenderer.create(React.createElement(Suspense, {
                fallback = React.createElement(Text, {
                    text = 'Loading...',
                }),
            }, React.createElement(LazyFoo, nil)), {unstable_isConcurrent = true})

            -- ROBLOX FIXME: in fakeImport, we call resolve() immediately instead of acting like a Promise
            -- as such, the Suspense fallback ('Loading...') never gets rendered
            jestExpect(Scheduler).toFlushAndYield({
                'Started loading',
                'Loading...',
            })
            jestExpect(root).never.toMatchRenderedOutput(React.createElement('div', nil, 'AB'))

            -- Promise.resolve()

            jestExpect(function()
                jestExpect(Scheduler).toFlushAndYield({
                    'A',
                    'B',
                })
            end).toErrorDev('    in Text (at **)\n' .. '    in Foo (at **)')
            jestExpect(root).toMatchRenderedOutput(React.createElement('div', nil, 'AB'))
        end)
        -- it('supports class and forwardRef components', _async(function()
        --     local LazyClass = lazy(function()
        --         local Foo = {}
        --         local FooMetatable = {__index = Foo}

        --         function Foo:render()
        --             return React.createElement(Text, {
        --                 text = 'Foo',
        --             })
        --         end

        --         return fakeImport(Foo)
        --     end)
        --     local LazyForwardRef = lazy(function()
        --         local Bar = {}
        --         local BarMetatable = {__index = Bar}

        --         function Bar:render()
        --             return React.createElement(Text, {
        --                 text = 'Bar',
        --             })
        --         end

        --         return fakeImport(React.forwardRef(function(props, ref)
        --             Scheduler.unstable_yieldValue('forwardRef')

        --             return React.createElement(Bar, {ref = ref})
        --         end))
        --     end)
        --     local ref = React.createRef()
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyClass, nil), React.createElement(LazyForwardRef, {ref = ref})), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('FooBar')
        --     expect(ref.current).toBe(nil)

        --     return _await(Promise.resolve(), function()
        --         expect(Scheduler).toFlushAndYield({
        --             'Foo',
        --             'forwardRef',
        --             'Bar',
        --         })
        --         expect(root).toMatchRenderedOutput('FooBar')
        --         expect(ref.current).not.toBe(nil)
        --     end)
        -- end))
        -- it('supports defaultProps defined on the memo() return value', _async(function()
        --     local Add = React.memo(function(props)
        --         return props.inner + props.outer
        --     end)

        --     Add.defaultProps = {inner = 2}

        --     local LazyAdd = lazy(function()
        --         return fakeImport(Add)
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyAdd, {outer = 2})), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('4')

        --     return _await(Promise.resolve(), function()
        --         expect(Scheduler).toFlushWithoutYielding()
        --         expect(root).toMatchRenderedOutput('4')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyAdd, {outer = 2})))
        --         expect(Scheduler).toFlushWithoutYielding()
        --         expect(root).toMatchRenderedOutput('4')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyAdd, {outer = 3})))
        --         expect(Scheduler).toFlushWithoutYielding()
        --         expect(root).toMatchRenderedOutput('5')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyAdd, {outer = 3})))
        --         expect(Scheduler).toFlushWithoutYielding()
        --         expect(root).toMatchRenderedOutput('5')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyAdd, {
        --             outer = 1,
        --             inner = 1,
        --         })))
        --         expect(Scheduler).toFlushWithoutYielding()
        --         expect(root).toMatchRenderedOutput('2')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyAdd, {
        --             outer = 1,
        --             inner = 1,
        --         })))
        --         expect(Scheduler).toFlushWithoutYielding()
        --         expect(root).toMatchRenderedOutput('2')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyAdd, {outer = 1})))
        --         expect(Scheduler).toFlushWithoutYielding()
        --         expect(root).toMatchRenderedOutput('3')
        --     end)
        -- end))
        -- it('merges defaultProps in the correct order', _async(function()
        --     local Add = React.memo(function(props)
        --         return props.inner + props.outer
        --     end)

        --     Add.defaultProps = {inner = 100}
        --     Add = React.memo(Add)
        --     Add.defaultProps = {
        --         inner = 2,
        --         outer = 0,
        --     }

        --     local LazyAdd = lazy(function()
        --         return fakeImport(Add)
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyAdd, {outer = 2})), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('4')

        --     return _await(Promise.resolve(), function()
        --         expect(Scheduler).toFlushWithoutYielding()
        --         expect(root).toMatchRenderedOutput('4')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyAdd, {outer = 3})))
        --         expect(Scheduler).toFlushWithoutYielding()
        --         expect(root).toMatchRenderedOutput('5')
        --         root.update(React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, React.createElement(LazyAdd, nil)))
        --         expect(Scheduler).toFlushWithoutYielding()
        --         expect(root).toMatchRenderedOutput('2')
        --     end)
        -- end))
        -- ROBLOX FIXME: needs a proper Promise to be returned from fakeImport
        xit('warns about ref on functions for lazy-loaded components', function()
            local LazyFoo = lazy(function()
                local Foo = function(props)
                    return React.createElement('div', nil)
                end

                return fakeImport(Foo)
            end)
            local ref = React.createRef()

            ReactTestRenderer.create(React.createElement(Suspense, {
                fallback = React.createElement(Text, {
                    text = 'Loading...',
                }),
            }, React.createElement(LazyFoo, {ref = ref})), {unstable_isConcurrent = true})
            jestExpect(Scheduler).toFlushAndYield({
                'Loading...',
            })

            -- return _await(Promise.resolve(), function()
            jestExpect(function()
                    jestExpect(Scheduler).toFlushAndYield({})
                end).toErrorDev('Function components cannot be given refs')
            -- end)
        end)
        -- it('should error with a component stack naming the resolved component', _async(function()
        --     local componentStackMessage
        --     local LazyText = lazy(function()
        --         return fakeImport(function()
        --             error(Error('oh no'))
        --         end)
        --     end)
        --     local ErrorBoundary = {}
        --     local ErrorBoundaryMetatable = {__index = ErrorBoundary}

        --     function ErrorBoundary.new()
        --         local self = setmetatable({}, ErrorBoundaryMetatable)
        --         local _temp5

        --         return
        --     end
        --     function ErrorBoundary:componentDidCatch(error, errMessage)
        --         componentStackMessage = normalizeCodeLocInfo(errMessage.componentStack)

        --         self.setState({error = error})
        --     end
        --     function ErrorBoundary:render()
        --         return(function()
        --             if self.state.error then
        --                 return nil
        --             end

        --             return self.props.children
        --         end)()
        --     end

        --     ReactTestRenderer.create(React.createElement(ErrorBoundary, nil, React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyText, {
        --         text = 'Hi',
        --     }))), {unstable_isConcurrent = true})
        --     expect(Scheduler).toFlushAndYield({
        --         'Loading...',
        --     })

        --     return _continue(_catch(function()
        --         return _awaitIgnored(Promise.resolve())
        --     end, _empty), function()
        --         expect(Scheduler).toFlushAndYield({})
        --         expect(componentStackMessage).toContain('in ResolvedText')
        --     end)
        -- end))
        -- it('should error with a component stack containing Lazy if unresolved', function()
        --     local componentStackMessage
        --     local LazyText = lazy(function()
        --         return{
        --             then = function(resolve, reject)
        --                 reject(Error('oh no'))
        --             end,
        --         }
        --     end)
        --     local ErrorBoundary = {}
        --     local ErrorBoundaryMetatable = {__index = ErrorBoundary}

        --     function ErrorBoundary.new()
        --         local self = setmetatable({}, ErrorBoundaryMetatable)
        --         local _temp6

        --         return
        --     end
        --     function ErrorBoundary:componentDidCatch(error, errMessage)
        --         componentStackMessage = normalizeCodeLocInfo(errMessage.componentStack)

        --         self.setState({error = error})
        --     end
        --     function ErrorBoundary:render()
        --         return(function()
        --             if self.state.error then
        --                 return nil
        --             end

        --             return self.props.children
        --         end)()
        --     end

        --     ReactTestRenderer.create(React.createElement(ErrorBoundary, nil, React.createElement(Suspense, {
        --         fallback = React.createElement(Text, {
        --             text = 'Loading...',
        --         }),
        --     }, React.createElement(LazyText, {
        --         text = 'Hi',
        --     }))))
        --     expect(Scheduler).toHaveYielded({})
        --     expect(componentStackMessage).toContain('in Lazy')
        -- end)
        -- it('mount and reorder lazy elements', _async(function()
        --     local Child = {}
        --     local ChildMetatable = {__index = Child}

        --     function Child:componentDidMount()
        --         Scheduler.unstable_yieldValue('Did mount: ' + self.props.label)
        --     end
        --     function Child:componentDidUpdate()
        --         Scheduler.unstable_yieldValue('Did update: ' + self.props.label)
        --     end
        --     function Child:render()
        --         return React.createElement(Text, {
        --             text = self.props.label,
        --         })
        --     end

        --     local lazyChildA = lazy(function()
        --         Scheduler.unstable_yieldValue('Init A')

        --         return fakeImport(React.createElement(Child, {
        --             key = 'A',
        --             label = 'A',
        --         }))
        --     end)
        --     local lazyChildB = lazy(function()
        --         Scheduler.unstable_yieldValue('Init B')

        --         return fakeImport(React.createElement(Child, {
        --             key = 'B',
        --             label = 'B',
        --         }))
        --     end)
        --     local lazyChildA2 = lazy(function()
        --         Scheduler.unstable_yieldValue('Init A2')

        --         return fakeImport(React.createElement(Child, {
        --             key = 'A',
        --             label = 'a',
        --         }))
        --     end)

        --     local function Parent(_ref2)
        --         local swap = _ref2.swap

        --         return React.createElement(Suspense, {
        --             fallback = React.createElement(Text, {
        --                 text = 'Loading...',
        --             }),
        --         }, (function()
        --             if swap then
        --                 return{lazyChildB2, lazyChildA2}
        --             end

        --             return{lazyChildA, lazyChildB}
        --         end)())
        --     end

        --     local lazyChildB2 = lazy(function()
        --         Scheduler.unstable_yieldValue('Init B2')

        --         return fakeImport(React.createElement(Child, {
        --             key = 'B',
        --             label = 'b',
        --         }))
        --     end)
        --     local root = ReactTestRenderer.create(React.createElement(Parent, {swap = false}), {unstable_isConcurrent = true})

        --     expect(Scheduler).toFlushAndYield({
        --         'Init A',
        --         'Loading...',
        --     })
        --     expect(root).not.toMatchRenderedOutput('AB')

        --     return _await(lazyChildA, function()
        --         expect(Scheduler).toFlushAndYield({
        --             'Init B',
        --         })

        --         return _await(lazyChildB, function()
        --             expect(Scheduler).toFlushAndYield({
        --                 'A',
        --                 'B',
        --                 'Did mount: A',
        --                 'Did mount: B',
        --             })
        --             expect(root).toMatchRenderedOutput('AB')
        --             root.update(React.createElement(Parent, {swap = true}))
        --             expect(Scheduler).toFlushAndYield({
        --                 'Init B2',
        --                 'Loading...',
        --             })

        --             return _await(lazyChildB2, function()
        --                 expect(Scheduler).toFlushAndYield({
        --                     'Init A2',
        --                     'Loading...',
        --                 })

        --                 return _await(lazyChildA2, function()
        --                     expect(Scheduler).toFlushAndYield({
        --                         'b',
        --                         'a',
        --                         'Did update: b',
        --                         'Did update: a',
        --                     })
        --                     expect(root).toMatchRenderedOutput('ba')
        --                 end)
        --             end)
        --         end)
        --     end)
        -- end))
    end)
end