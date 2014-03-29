#= require jquery-fileupload/jquery.ui.widget
#= require jquery-fileupload/load-image.min
#= require jquery-fileupload/canvas-to-blob.min
#= require jquery-fileupload/jquery.iframe-transport
#= require jquery-fileupload/jquery.fileupload
#= require jquery-fileupload/jquery.fileupload-process
#= require jquery-fileupload/jquery.fileupload-image
#= require vendors/tmpl

$ = jQuery

$.fn.S3Uploader = (options) ->

  # support multiple elements
  if @length > 1
    @each ->
      $(this).S3Uploader options

    return this

  $uploadForm = this

  settings =
    path: ''
    additional_data: null
    before_send: null
    remove_completed_progress_bar: true
    remove_failed_progress_bar: false
    callback_url: null
    callback_method: null
    image_min_width: 0
    image_min_height: 0
    image_max_width: 800
    image_max_height: 800

  $.extend settings, options

  current_files = []

  setUploadForm = ->
    $uploadForm.fileupload
      disableImageResize: /Android(?!.*Chrome)|Opera/.test(window.navigator && navigator.userAgent)
      imageMinWidth: settings.image_min_width
      imageMinHeight: settings.image_min_height
      imageMaxWidth: settings.image_max_width
      imageMaxHeight: settings.image_max_height
      disableImagePreview: true

      send: (e, data) ->
        file = data.files[0]
        if $('#template-upload').length > 0
          data.context = $($.trim(tmpl("template-upload", file)))
          data.context = settings.progress_bar_target
        
        if settings.before_send
          settings.before_send(file)

      start: (e) ->
        $uploadForm.trigger("s3_uploads_start", [e])

      progress: (e, data) ->
        if data.context
          progress = parseInt(data.loaded / data.total * 100, 10)
          data.context.find('.bar').css('width', progress + '%')

      done: (e, data) ->
        content = build_content_object $uploadForm, data.files[0], data.result
        if settings.callback_url
          content[$uploadForm.data('callback-param')] = content.url

          $.ajax
            type: settings.callback_method
            url: settings.callback_url
            data: content
            beforeSend: ( xhr, settings )       -> $uploadForm.trigger( 'ajax:beforeSend', [xhr, settings] )
            complete:   ( xhr, status )         -> $uploadForm.trigger( 'ajax:complete', [xhr, status] )
            success:    ( data, status, xhr )   -> $uploadForm.trigger( 'ajax:success', [data, status, xhr] )
            error:      ( xhr, status, error )  -> $uploadForm.trigger( 'ajax:error', [xhr, status, error] )

        content = build_content_object $uploadForm, data.files[0], data.result
        $uploadForm.trigger("s3_upload_complete", [content])

      fail: (e, data) ->
        content = build_content_object $uploadForm, data.files[0], data.result
        content.error_thrown = data.errorThrown

        $uploadForm.trigger("s3_upload_failed", [content])

      formData: (form) ->
        data = form.serializeArray()
        fileType = ""
        if "type" of @files[0]
          fileType = @files[0].type
        data.push
          name: "Content-Type"
          value: fileType

        @files[0].unique_id = Math.random().toString(36).substr(2,16)
        key = $uploadForm.data("key").replace('{timestamp}', new Date().getTime()).replace('{unique_id}', @files[0].unique_id)
        key_field = $.grep data, (n) ->
          n if n.name == "key"

        if key_field.length > 0
          key_field[0].value = settings.path + key

        unless 'FormData' of window
          $uploadForm.find("input[name='key']").val(settings.path + key)

        #data[1].value = settings.path + data[1].value
        data

  build_content_object = ($uploadForm, file, result) ->
    content = {}
    if result # Use the S3 response to set the URL to avoid character encodings bugs
      content.url            = $(result).find("Location").text()
      content.filepath       = $('<a />').attr('href', content.url)[0].pathname
    else # IE <= 9 retu      rn a null result object so we use the file object instead
      domain                 = $uploadForm.attr('action')
      content.filepath       = $uploadForm.find('input[name=key]').val().replace('/${filename}', '')
      content.url            = domain + content.filepath + '/' + encodeURIComponent(file.name)

    content.filename         = file.name
    content.filesize         = file.size if 'size' of file
    content.lastModifiedDate = file.lastModifiedDate if 'lastModifiedDate' of file
    content.filetype         = file.type if 'type' of file
    content.unique_id        = file.unique_id if 'unique_id' of file
    content.relativePath     = build_relativePath(file) if has_relativePath(file)
    content = $.extend content, settings.additional_data if settings.additional_data
    content

  has_relativePath = (file) ->
    file.relativePath || file.webkitRelativePath

  build_relativePath = (file) ->
    file.relativePath || (file.webkitRelativePath.split("/")[0..-2].join("/") + "/" if file.webkitRelativePath)

  #public methods
  @initialize = ->
    $uploadForm.data("key", $uploadForm.find("input[name='key']").val())

    setUploadForm()
    this

  @path = (new_path) ->
    settings.path = new_path

  @additional_data = (new_data) ->
    settings.additional_data = new_data

  @callback_url = (new_callback_url) ->
    settings.callback_url = new_callback_url

  @initialize()

$ = jQuery

$.fn.S3UploaderSimple = (options) ->

  # support multiple elements
  if @length > 1
    @each ->
      $(this).S3Uploader options

    return this

  $uploaderElement = this

  settings =
    path: ''
    additional_data: null
    before_add: null
    after: null
    remove_completed_progress_bar: true
    remove_failed_progress_bar: false
    progress_bar_target: null
    click_submit_target: null

  $.extend settings, options

  current_files = []
  forms_for_submit = []
  if settings.click_submit_target
    settings.click_submit_target.click ->
      form.submit() for form in forms_for_submit
      false

  setUploadElement = ->
    $uploaderElement.fileupload
      disableImagePreview: true
      url: settings.url if settings.url

      add: (e, data) ->
        file = data.files[0]
        file.unique_id = Math.random().toString(36).substr(2,16)

        unless settings.before_add and not settings.before_add(file)
          current_files.push data
          if settings.progress_bar_target
            data.context = $($.trim(tmpl("template-upload", file))) if $('#template-upload').length > 0
            $(data.context).appendTo(settings.progress_bar_target($(this)) || $uploaderElement)
          if settings.click_submit_target
           forms_for_submit.push data
          else
            data.submit()

      start: (e) ->
        $uploaderElement.trigger("s3_uploads_start", [e])

      progress: (e, data) ->
        if data.context
          progress = parseInt(data.loaded / data.total * 100, 10)
          data.context.find('.bar').css('width', progress + '%')

      done: (e, data) ->
        content = build_content_object $uploaderElement, data.files[0], data.result

        to = $uploaderElement.data('callback-url')
        if to
          content[$uploaderElement.data('callback-param')] = content.url

          element = $(this)
          $.ajax
            type: $uploaderElement.data('callback-method')
            url: to
            data: content
            beforeSend: ( xhr, settings )       -> element.trigger( 'ajax:beforeSend', [xhr, settings] )
            complete:   ( xhr, status )         -> element.trigger( 'ajax:complete', [xhr, status] )
            success:    ( data, status, xhr )   -> element.trigger( 'ajax:success', [data, status, xhr] )
            error:      ( xhr, status, error )  -> element.trigger( 'ajax:error', [xhr, status, error] )

        data.context.remove() if data.context && settings.remove_completed_progress_bar # remove progress bar
        $uploaderElement.trigger("s3_upload_complete", [content])

        settings.after(content) if settings.after

        current_files.splice($.inArray(data, current_files), 1) # remove that element from the array
        $uploaderElement.trigger("s3_uploads_complete", [content]) unless current_files.length

      fail: (e, data) ->
        content = build_content_object $uploaderElement, data.files[0], data.result
        content.error_thrown = data.errorThrown

        data.context.remove() if data.context && settings.remove_failed_progress_bar # remove progress bar
        $uploaderElement.trigger("s3_upload_failed", [content])

      formData: (form) ->
        data = $('.s3upload_hidden_fields').serializeArray()
        fileType = ""
        if "type" of @files[0]
          fileType = @files[0].type
        data.push
          name: "Content-Type"
          value: fileType

        # substitute upload timestamp and unique_id into key
        key = data[0].value.replace('{timestamp}', new Date().getTime()).replace('{unique_id}', @files[0].unique_id)
        data[0].value = settings.path + key
        data

  build_content_object = ($uploaderElement, file, result) ->
    content = {}
    if result # Use the S3 response to set the URL to avoid character encodings bugs
      content.url      = $(result).find("Location").text()
      content.filepath = $('<a />').attr('href', content.url)[0].pathname
    #else # IE <= 9 return a null result object so we use the file object instead
      #domain           = $uploaderElement.attr('action')
      #content.filepath = settings.path + $uploaderElement.find('input[name=key]').val().replace('/${filename}', '')
      #content.url      = domain + content.filepath + '/' + encodeURIComponent(file.name)

    content.filename   = file.name
    content.filesize   = file.size if 'size' of file
    content.filetype   = file.type if 'type' of file
    content.unique_id  = file.unique_id if 'unique_id' of file
    content = $.extend content, settings.additional_data if settings.additional_data
    content

  #public methods
  @initialize = ->
    setUploadElement()
    this

  @path = (new_path) ->
    settings.path = new_path

  @additional_data = (new_data) ->
    settings.additional_data = new_data

  @initialize()