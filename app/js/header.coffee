class App.Header extends Backbone.View
  el: 'header'

  events: {
    'keyup #search': 'search'
    'focus #search': 'enableShortcuts'
    'blur #search': 'disableShortcuts'
  }

  prevTerms: ''

  initialize: (options) ->
    @layout = options.layout
    @layout.on('change', @highlightNav)
    @$links = @$('nav a')
    @links = ($(a) for a in @$links)
    @$loading = @$('.loading')
    @listenTo(App.router, 'percentage', @animateLoadingBar)

    @$search = @$('#search')
    if @$el
      @prevTerms = @$search.val()
    @executeSearch = _.debounce(@_executeSearch, 350)
    @listenTo(@, 'placed', =>
      search = @$('input#search').attr('autocomplete', 'off')
    )
    @setupShortcuts()

    $(window).on('popstate', @resetSearch)
    $(window).on('pushstate', @resetSearch)

    if window.navigator.platform.indexOf('Mac') != -1
      keys = @$('span.keys')
      keys.text(keys.text().replace('ctrl', 'cmd'))

    @refreshAd()

  cleanup: =>
    @disableShortcuts()
    window.keymaster.unbind('enter', 'search')
    window.keymaster.unbind('up', 'search')
    window.keymaster.unbind('down', 'search')
    window.keymaster.unbind('enter')

  isElementInViewport: (el) ->
    rect = el.getBoundingClientRect()

    return (
        rect.top >= 0 &&
        rect.left >= 0 &&
        rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
        rect.right <= (window.innerWidth || document.documentElement.clientWidth)
    )

  search: (e) =>
    input = $(e.target)
    terms = input.val()

    if @prevTerms == terms
      return

    @prevTerms = terms

    # If the terms are removed when not on the search page, do nothing
    if terms == '' and App.router.path().indexOf('/search') == -1
      return

    # If the user changes the search terms, cancel any in-progress navigation
    App.router.cancelNavigation()
    @executeSearch(terms)

  _executeSearch: (terms) =>
    route = 'index'
    if terms
      route = 'search'

    url = App.router.url(route, {terms: terms})
    App.router.changeUrl(url)

  resetSearch: =>
    if App.router.path().indexOf('/search') != -1
      terms = App.router.path().replace(/^\/search\/?([^\/]+)?$/, '$1')
      terms = decodeURIComponent(terms)
      @$search.focus()
      @moveCursor(@$search[0])
    else
      terms = ''
      if App.router.path() != '/'
        @$search.blur()
    @$search.val(terms)

  # Focus an input and move the cursor to the last char
  moveCursor: (elem) ->
    elemLen = elem.value.length
    if document.selection
      elem.focus()
      oSel = document.selection.createRange()
      oSel.moveStart('character', -elemLen)
      oSel.moveStart('character', elemLen)
      oSel.moveEnd('character', 0)
      oSel.select()
    else if elem.selectionStart or elem.selectionStart == 0
      elem.selectionStart = elemLen
      elem.selectionEnd = elemLen

  enableShortcuts: =>
    window.keymaster.setScope('search')

  disableShortcuts: =>
    window.keymaster.setScope('all')

  setupShortcuts: =>
    # When JS is available, prevent default form action
    window.keymaster('enter', (e) ->
      e.preventDefault()
    )

    # Allow users to use ctrl+shift+p or cmd+shift+p to focus search
    window.keymaster('command+shift+p, ctrl+shift+p', (e) =>
      @$search.focus()
    )

    window.keymaster('enter', 'search', (e) =>
      e.preventDefault()
      if @layout.view.name != 'Search'
        return
      href = @layout.view.$results.find('li.hover a').attr('href')
      App.router.changeUrl(href)
    )

    window.keymaster('up', 'search', (e) =>
      e.preventDefault()
      if @layout.view.name != 'Search'
        return
      hovered = @layout.view.$results.find('li.hover')
      if hovered.length == 0 or hovered.is(':first-child')
        selected = @layout.view.$results.find('li:last-child')
      else
        selected = hovered.prev()
      if not selected[0]
        return
      hovered.removeClass('hover')
      selected.addClass('hover')
      if not @isElementInViewport(selected[0])
        offset = selected.offset()
        $('html, body').animate({
            scrollTop: offset.top - 20
        }, 150)
    )

    window.keymaster('down', 'search', (e) =>
      e.preventDefault()
      if @layout.view.name != 'Search'
        return
      hovered = @layout.view.$results.find('li.hover')
      if hovered.length == 0 or hovered.is(':last-child')
        selected = @layout.view.$results.find('li:first-child')
      else
        selected = hovered.next()
      if not selected[0]
        return
      hovered.removeClass('hover')
      selected.addClass('hover')
      if not @isElementInViewport(selected[0])
        offset = selected.offset()
        $('html, body').animate({
            scrollTop: offset.top - 20
        }, 150)
    )

  highlightNav: =>
    @$links.removeClass('active')
    url = App.router.path()
    found = false
    for link in @links
      if url.indexOf(link.attr('href')) == 0
        link.addClass('active')
        found = true
        break
    if not found and url.indexOf('/packages/') == 0
      @$('a[href^="/browse"]').addClass('active')

  animateLoadingBar: (percentage) =>

    dimension = 'height'
    if parseInt(window.innerWidth, 10) <= 600
      dimension = 'width'

    complete = null
    if percentage >= 100
      percentage = 100
      # Turn off CSS transitions when resetting the loading bar
      # so it does not animate shrinking back to 0
      complete = =>
        @$loading.css({
          'transition': 'none',
          '-moz-transition': 'none',
          '-webkit-transition': 'none',
        })
        @$loading.removeData('css-transition')
        @$loading.css(dimension, '0')
      setTimeout(complete, 150)

    # When loading starts, enable the dimension transition
    # for a nice silky smooth loading bar
    if not @$loading.data('css-transition')
      @$loading.css({
        'transition': dimension + ' .15s ease-in-out',
        '-moz-transition': dimension + ' .15s ease-in-out',
        '-webkit-transition': dimension + ' .15s ease-in-out'
      })
      @$loading.data('css-transition', true)

    @$loading.css(dimension, percentage + '%')

  refreshAd: (showing) =>
    # Remove and recreate the ad placeholder
    adJsEls = $('#_fusionads_js, #bsap_1332, #_fusion_projs, #_bsaPRO_js, #auto_1')
    adEl = $('#fusionads')
    previouslyLoaded = adJsEls.length > 0

    if not previouslyLoaded
      container = $('<div id="fusion-container"></div>')
      $('#nav_container').append(container)
    else
      container = $('#fusion-container')
      serve = $('#bsap_1332').data('serve')
      adEl.attr('id', 'fusionads-old')

    adJsEls.remove()

    if previouslyLoaded
      window._bsaPRO_loaded = false
      delete window._bsaPRO
      delete window._bsap_serving_callback
      delete window._fusion
      delete window._fusion_zone
      delete window['bsa_' + serve]

    script = document.createElement('script')
    script.src = '//cdn.fusionads.net/fusion.js?zoneid=1332&serve=C6SDP2Y&placement=sublimewbond'
    script.id = '_fusionads_js'

    # Only run the reload code if it is present
    runInterval = null
    counter = 0
    script.onload = ->
      runInterval = setInterval((->
        counter += 1

        # Give up after a while, presuming the JS must have been blocked
        if counter > 100
          clearInterval(runInterval)

        if window._bsaPRO
          clearInterval(runInterval)
          window._bsaPRO()
      ), 50)

    container[0].appendChild(script)

    # Dynamically add the loaded class as soon as the div is added. This allows
    # for a cross-fade when replacing an existing ad, so we don't have to have
    # a set height for the container.
    fadeIn = ->
      ad = $('#fusionads')
      return if ad.length == 0
      # Stop the transition if the image has not loaded yet so we don't get
      # a flash of the image loading
      return if ad.find('img')[0].naturalWidth == 0

      clearInterval(fadeInterval)

      ad.addClass('loaded')

      adEl.addClass('outgoing').removeClass('loaded')
      if adEl.find('.fusion-text').text() == ad.find('.fusion-text').text()
        adEl.addClass('same')

      setTimeout((-> adEl.remove()), 200)

    fadeInterval = setInterval(fadeIn, 50)
    fadeIn()
