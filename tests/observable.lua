describe('Observable', function()
  describe('create', function()
    it('returns an Observable', function()
      local observable = Rx.Observable.create()
      expect(observable).to.be.an(Rx.Observable)
    end)

    it('sets _subscribe to the first argument it was passed', function()
      local subscribe = function() end
      local observable = Rx.Observable.create(subscribe)
      expect(observable._subscribe).to.equal(subscribe)
    end)
  end)

  describe('subscribe', function()
    it('passes the first argument to _subscribe if it is a table', function()
      local observable = Rx.Observable.of()
      local observer = Rx.Observer.create()
      local function run() observable:subscribe(observer) end
      expect(spy(observable, '_subscribe', run)).to.equal({{observer}})
    end)

    it('creates a new Observer using the first three arguments and passes it to _subscribe if the first argument is not a table', function()
      local observable = Rx.Observable.of()
      local a, b, c = function() end, function() end, function() end
      local function run() observable:subscribe(a, b, c) end
      local observer = spy(observable, '_subscribe', run)[1][1]
      expect(observer).to.be.an(Rx.Observer)
      expect(observer._onNext).to.equal(a)
      expect(observer._onError).to.equal(b)
      expect(observer._onCompleted).to.equal(c)
    end)
  end)

  describe('empty', function()
    it('returns an Observable that does not produce any values', function()
      local observable = Rx.Observable.empty()
      local onNext, onError, onCompleted = observableSpy(observable)
      expect(#onNext).to.equal(0)
      expect(#onError).to.equal(0)
      expect(#onCompleted).to.equal(1)
    end)
  end)

  describe('never', function()
    it('returns an Observable that does not produce values or complete', function()
      local observable = Rx.Observable.never()
      local onNext, onError, onCompleted = observableSpy(observable)
      expect(#onNext).to.equal(0)
      expect(#onError).to.equal(0)
      expect(#onCompleted).to.equal(0)
    end)
  end)

  describe('throw', function()
    it('returns an Observable that produces an error', function()
      local observable = Rx.Observable.throw('message')
      expect(function() observable:subscribe() end).to.fail()
    end)
  end)

  describe('of', function()
    it('returns an Observable that produces the supplied arguments and completes', function()
      local observable = Rx.Observable.of(1, 2, 3)
      expect(observable).to.produce(1, 2, 3)
    end)

    it('returns an Observable that produces nil and completes if nil is passed', function()
      local observable = Rx.Observable.of(nil)
      expect(observable).to.produce(nil)
    end)

    it('returns an Observable that produces nothing if no arguments are passed', function()
      local observable = Rx.Observable.of()
      expect(observable).to.produce.nothing()
    end)
  end)

  describe('fromRange', function()
    it('errors if no arguments are provided', function()
      local run = function() Rx.Observable.fromRange():subscribe() end
      expect(run).to.fail()
    end)

    describe('with one argument', function()
      it('returns an Observable that produces elements sequentially from 1 to the first argument', function()
        local observable = Rx.Observable.fromRange(5)
        expect(observable).to.produce(1, 2, 3, 4, 5)
      end)

      it('returns an Observable that produces no elements if the first argument is less than one', function()
        local observable = Rx.Observable.fromRange(0)
        expect(observable).to.produce.nothing()
      end)
    end)

    describe('with two arguments', function()
      it('returns an Observable that produces elements sequentially from the first argument to the second argument', function()
        local observable = Rx.Observable.fromRange(1, 5)
        expect(observable).to.produce(1, 2, 3, 4, 5)
      end)

      it('returns an Observable that produces no elements if the first argument is greater than the second argument', function()
        local observable = Rx.Observable.fromRange(1, -5)
        expect(observable).to.produce.nothing()
      end)
    end)

    describe('with three arguments', function()
      it('returns an Observable that produces elements sequentially from the first argument to the second argument, incrementing by the third argument', function()
        local observable = Rx.Observable.fromRange(1, 5, 2)
        expect(observable).to.produce(1, 3, 5)
      end)
    end)
  end)

  describe('fromTable', function()
    it('errors if the first argument is not a table', function()
      local function run() Rx.Observable.fromTable():subscribe() end
      expect(run).to.fail()
    end)

    describe('with one argument', function()
      it('returns an Observable that produces values by iterating the table using pairs', function()
        local input = {foo = 'bar', 1, 2, 3}
        local observable = Rx.Observable.fromTable(input)
        local result = {}
        for key, value in pairs(input) do table.insert(result, {value}) end
        expect(observable).to.produce(result)
      end)
    end)

    describe('with two arguments', function()
      it('returns an Observable that produces values by iterating the table using the second argument', function()
        local input = {foo = 'bar', 3, 4, 5}
        local observable = Rx.Observable.fromTable(input, ipairs)
        expect(observable).to.produce(3, 4, 5)
      end)
    end)

    describe('with three arguments', function()
      it('returns an Observable that produces value-key pairs by iterating the table if the third argument is true', function()
        local input = {foo = 'bar', 3, 4, 5}
        local observable = Rx.Observable.fromTable(input, ipairs, true)
        expect(observable).to.produce({{3, 1}, {4, 2}, {5, 3}})
      end)
    end)
  end)

  describe('fromCoroutine', function()
    it('returns an Observable that produces a value whenever the first argument yields a value', function()
      local coroutine = coroutine.create(function()
        coroutine.yield(1)
        coroutine.yield(2)
        return 3
      end)

      Rx.scheduler = Rx.CooperativeScheduler.create()
      local observable = Rx.Observable.fromCoroutine(coroutine, Rx.scheduler)
      local onNext, onError, onCompleted = observableSpy(observable)
      repeat Rx.scheduler:update()
      until Rx.scheduler:isEmpty()
      expect(onNext).to.equal({{1}, {2}, {3}})
    end)

    it('accepts a function as the first argument and wraps it into a coroutine', function()
      local coroutine = function()
        coroutine.yield(1)
        coroutine.yield(2)
        return 3
      end

      Rx.scheduler = Rx.CooperativeScheduler.create()
      local observable = Rx.Observable.fromCoroutine(coroutine, Rx.scheduler)
      local onNext, onError, onCompleted = observableSpy(observable)
      repeat Rx.scheduler:update()
      until Rx.scheduler:isEmpty()
      expect(onNext).to.equal({{1}, {2}, {3}})
    end)

    it('shares values among Observers when the first argument is a coroutine', function()
      local coroutine = coroutine.create(function()
        coroutine.yield(1)
        coroutine.yield(2)
        return 3
      end)

      Rx.scheduler = Rx.CooperativeScheduler.create()
      local observable = Rx.Observable.fromCoroutine(coroutine, Rx.scheduler)
      local onNextA = observableSpy(observable)
      local onNextB = observableSpy(observable)
      repeat Rx.scheduler:update()
      until Rx.scheduler:isEmpty()
      expect(onNextA).to.equal({{1}, {3}})
      expect(onNextB).to.equal({{2}})
    end)

    it('uses a unique coroutine for each Observer when the first argument is a function', function()
      local coroutine = function()
        coroutine.yield(1)
        coroutine.yield(2)
        return 3
      end

      Rx.scheduler = Rx.CooperativeScheduler.create()
      local observable = Rx.Observable.fromCoroutine(coroutine, Rx.scheduler)
      local onNextA = observableSpy(observable)
      local onNextB = observableSpy(observable)
      repeat Rx.scheduler:update()
      until Rx.scheduler:isEmpty()
      expect(onNextA).to.equal({{1}, {2}, {3}})
      expect(onNextB).to.equal({{1}, {2}, {3}})
    end)
  end)

  describe('fromFileByLine', function()
    local oldIO = _G['io']
    _G['io'] = {}

    local filename = 'file.txt'

    it('returns an observable', function()
      expect(Rx.Observable.fromFileByLine(filename)).to.be.an(Rx.Observable)
    end)

    it('errors if the file does not exist', function()
      io.open = function() return nil end
      local onError = spy()
      Rx.Observable.fromFileByLine(filename):subscribe(nil, onError, nil)
      expect(onError).to.equal({{ filename }})
    end)

    it('returns an Observable that produces the lines of the file', function()
      io.open = function() return { close = function() end } end
      io.lines = function()
        local lines = { 'line1', 'line2', 'line3' }
        local i = 0
        return function()
          i = i + 1
          return lines[i]
        end
      end

      expect(Rx.Observable.fromFileByLine(filename)).to.produce('line1', 'line2', 'line3')
    end)

    io = oldIO
  end)

  describe('defer', function()
    it('returns an Observable', function()
      expect(Rx.Observable.defer(function() end)).to.be.an(Rx.Observable)
    end)

    it('fails if no factory is specified', function()
      expect(function () Rx.Observable.defer() end).to.fail()
    end)

    it('fails if the factory does not return an Observable', function()
      expect(function () Rx.Observable.defer(function() end):subscribe() end).to.fail()
    end)

    it('uses the factory function to create a new Observable for each subscriber', function()
      local i = 0
      local function factory()
        i = i + 1
        return Rx.Observable.fromRange(i, 3)
      end
      expect(Rx.Observable.defer(factory)).to.produce(1, 2, 3)
      expect(Rx.Observable.defer(factory)).to.produce(2, 3)
      expect(Rx.Observable.defer(factory)).to.produce(3)
    end)

    it('returns Observables that return subscriptions from their subscribe function', function()
      local subscription = Rx.Subscription.create()
      local function factory()
        return Rx.Observable.create(function()
          return subscription
        end)
      end

      expect(Rx.Observable.defer(factory):subscribe()).to.equal(subscription)
    end)
  end)

  describe('replicate', function()
    it('returns an Observable', function()
      expect(Rx.Observable.replicate()).to.be.an(Rx.Observable)
    end)

    it('returns an Observable that produces the first argument a specified number of times', function()
      expect(Rx.Observable.replicate(1, 3)).to.produce(1, 1, 1)
    end)

    it('produces nothing if the count is less than or equal to zero', function()
      expect(Rx.Observable.replicate(1, 0)).to.produce.nothing()
      expect(Rx.Observable.replicate(1, -1)).to.produce.nothing()
    end)
  end)

  describe('dump', function()
  end)

  dofile('tests/all.lua')
  dofile('tests/amb.lua')
  dofile('tests/average.lua')
  dofile('tests/buffer.lua')
  dofile('tests/catch.lua')
  dofile('tests/combineLatest.lua')
  dofile('tests/compact.lua')
  dofile('tests/concat.lua')
  dofile('tests/contains.lua')
  dofile('tests/count.lua')
  dofile('tests/defaultIfEmpty.lua')
  dofile('tests/distinct.lua')
  dofile('tests/distinctUntilChanged.lua')
  dofile('tests/elementAt.lua')
  dofile('tests/filter.lua')
  dofile('tests/find.lua')
  dofile('tests/first.lua')
  dofile('tests/flatMap.lua')
  dofile('tests/flatMapLatest.lua')
  dofile('tests/flatten.lua')
  dofile('tests/ignoreElements.lua')
  dofile('tests/last.lua')
  dofile('tests/map.lua')
  dofile('tests/max.lua')
  dofile('tests/min.lua')
  dofile('tests/merge.lua')
  dofile('tests/pack.lua')
  dofile('tests/partition.lua')
  dofile('tests/pluck.lua')
  dofile('tests/reduce.lua')
  dofile('tests/reject.lua')
  dofile('tests/retry.lua')
  dofile('tests/sample.lua')
  dofile('tests/scan.lua')
  dofile('tests/skip.lua')
  dofile('tests/skipLast.lua')
  dofile('tests/skipUntil.lua')
  dofile('tests/skipWhile.lua')
  dofile('tests/startWith.lua')
  dofile('tests/sum.lua')
  dofile('tests/switch.lua')
  dofile('tests/take.lua')
  dofile('tests/takeLast.lua')
  dofile('tests/takeUntil.lua')
  dofile('tests/takeWhile.lua')
  dofile('tests/tap.lua')
  dofile('tests/unpack.lua')
  dofile('tests/unwrap.lua')
  dofile('tests/window.lua')
  dofile('tests/withLatestFrom.lua')
  dofile('tests/zip.lua')
end)
