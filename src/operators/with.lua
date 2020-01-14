local Observable = require 'observable'
local util = require 'util'

--- Returns an Observable that produces a new value every time the original or all other specified
-- Observables produce one. nil is used for Observables that have not produced a value yet.
-- Note that only the first argument from each source Observable is used.
-- @arg {Observable...} sources - The other Observables to include into the result.
-- @returns {Observable}
function Observable:with(...)
  local sources = {...}

  return Observable.create(function(observer)
    local subscriptions = {}
    local remaining = #sources + 1
    local latest = setmetatable({}, {__len = util.constant(remaining)})

    local function onNthNext(i)
      return function(value)
        latest[i] = value
        return observer:onNext(util.unpack(latest))
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      remaining = remaining - 1
      if remaining == 0 then
        return observer:onCompleted()
      end
    end

    for i = 1, #sources do
      subscriptions[i] = sources[i]:subscribe(onNthNext(i + 1), onError, onCompleted)
    end

    subscriptions[#sources + 1] = self:subscribe(onNthNext(1), onError, onCompleted)
    return Subscription.create(function ()
      for i = 1, #sources + 1 do
        if subscriptions[i] then subscriptions[i]:unsubscribe() end
      end
    end)
  end)
end
