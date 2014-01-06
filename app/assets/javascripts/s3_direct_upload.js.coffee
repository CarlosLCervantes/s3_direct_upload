#= require jquery-fileupload/jquery.ui.widget
#= require jquery-fileupload/load-image.min
#= require jquery-fileupload/canvas-to-blob.min
#= require jquery-fileupload/jquery.iframe-transport
#= require jquery-fileupload/jquery.fileupload
#= require jquery-fileupload/jquery.fileupload-process
#= require jquery-fileupload/jquery.fileupload-image

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
        callback_url = $uploadForm.data('callback-url')
        if callback_url
          content[$uploadForm.data('callback-param')] = content.url

          $.ajax
            type: $uploadForm.data('callback-method')
            url: callback_url
            data: content
            beforeSend: ( xhr, settings )       -> $uploadForm.trigger( 'ajax:beforeSend', [xhr, settings] )
            complete:   ( xhr, status )         -> $uploadForm.trigger( 'ajax:complete', [xhr, status] )
            success:    ( data, status, xhr )   -> $uploadForm.trigger( 'ajax:success', [data, status, xhr] )
            error:      ( xhr, status, error )  -> $uploadForm.trigger( 'ajax:error', [xhr, status, error] )

        data.context.remove() if data.context && settings.remove_completed_progress_bar # remove progress bar
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
          name: "content-type"
          value: fileType

        key = $uploadForm.data("key").replace('{timestamp}', new Date().getTime()).replace('{unique_id}', @files[0].unique_id)

        # substitute upload timestamp and unique_id into key
        key_field = $.grep data, (n) ->
          n if n.name == "key"

        if key_field.length > 0
          key_field[0].value = settings.path + key

        # IE <= 9 doesn't have XHR2 hence it can't use formData
        # replace 'key' field to submit form
        unless 'FormData' of window
          $uploadForm.find("input[name='key']").val(settings.path + key)
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
      content.filetype         = file.type if 'type' of file
      content = $.extend content, settings.additional_data if settings.additional_data
      content

  #public methods
  @initialize = ->
    setUploadForm()
    this

  @path = (new_path) ->
    settings.path = new_path

  @additional_data = (new_data) ->
    settings.additional_data = new_data

  @initialize()
