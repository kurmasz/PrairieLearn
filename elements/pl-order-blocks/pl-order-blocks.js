/* eslint-env jquery, browser */

window.PLOrderBlocks = function (uuid, options) {
  const TABWIDTH = 50; // defines how many px the answer block is indented by, when the student
  // drags and indents a block
  let maxIndent = options.maxIndent; // defines the maximum number of times an answer block can be indented
  let enableIndentation = options.enableIndentation;

  let optionsElementId = '#order-blocks-options-' + uuid;
  let dropzoneElementId = '#order-blocks-dropzone-' + uuid;

  function setAnswer() {
    var answerObjs = $(dropzoneElementId).children();
    var studentAnswers = [];
    for (var i = 0; i < answerObjs.length; i++) {
      if (!$(answerObjs[i]).hasClass('info-fixed')) {
        var answerText = answerObjs[i].getAttribute('data-string');
        var answerUuid = answerObjs[i].getAttribute('data-uuid');
        var answerIndent = null;
        if (enableIndentation) {
          answerIndent = parseInt($(answerObjs[i]).css('marginLeft').replace('px', ''));
          answerIndent = Math.round(answerIndent / TABWIDTH); // get how many times the answer is indented
        }

        var answer = {
          inner_html: answerText,
          indent: answerIndent,
          uuid: answerUuid,
        };
        studentAnswers.push(answer);
      }
    }

    var textfieldName = '#' + uuid + '-input';
    $(textfieldName).val(JSON.stringify(studentAnswers));
  }

  function calculateIndent(ui, parent) {
    if (!parent[0].classList.contains('dropzone') || !enableIndentation) {
      // don't indent on option panel or solution panel with indents explicitly disabled
      return 0;
    }

    let leftDiff = ui.position.left - parent.position().left;
    leftDiff = Math.round(leftDiff / TABWIDTH) * TABWIDTH;
    let currentIndent = ui.item[0].style.marginLeft;
    if (currentIndent !== '') {
      leftDiff += parseInt(currentIndent);
    }

    // limit leftDiff to be in within the bounds of the drag and drop box
    // that is, at least indented 0 times, or at most indented by MAX_INDENT times
    leftDiff = Math.min(leftDiff, TABWIDTH * maxIndent);
    leftDiff = Math.max(leftDiff, 0);

    return leftDiff;
  }

  function placePairingIndicators() {
      // TODO: add in some UI indicator for the paired disttractors
      // runestone/parsons/js/parsons.js does something like
    //   for (i = 0; i < pairedBins.length; i++) {
    //     var pairedDiv = document.createElement("div");
    //     $(pairedDiv).addClass("paired");
    //     $(pairedDiv).html(
    //         "<span id= 'st' style = 'vertical-align: middle; font-weight: bold'>or{</span>"
    //     );
    //     pairedDivs.push(pairedDiv);
    //     this.sourceArea.appendChild(pairedDiv);
    // }
    let answerObjs = $(optionsElementId).children().toArray();
    // let groupsHandled = set();

    // for (let block of answerObjs) {
    //   let distractorGroup = block[0].getAttribute('data-distractor-group');
    //   let otherBlock = answerObjs.find((block) => block[0].getAttribute('data-distractor-group') == distractorGroup);

    //   let pairedIndicator = document.createElement("div");
    // }
    let getDistractorGroup = block => block.getAttribute('data-distractor-group');
    let distractorGroups = answerObjs.filter(block => getDistractorGroup(block)).sort((a,b) => getDistractorGroup(a) >= getDistractorGroup(b));
    for (let i = 0; i < distractorGroups.length; ++i) {
      if (i == distractorGroups.length - 1 ||
        (getDistractorGroup(distractorGroups[i]) != getDistractorGroup(distractorGroups[i + 1]))) { // handl
        // only one of the two is in this dropzone, just have a little thing behind it, no text
      } else {
        // move one to by by the other, put the big thing behind them both
        distractorGroups[i].insertAdjacentElement('afterend', distractorGroups[i + 1])
        ++i;
      }
    }
  }

  let sortables = optionsElementId + ', ' + dropzoneElementId;
  $(sortables).sortable({
    items: ':not(.pl-order-blocks-pairing-indicator)',
    // We add `a` to the default list of tags to account for help
    // popover triggers.
    cancel: 'input,textarea,button,select,option,a',
    connectWith: sortables,
    placeholder: 'ui-state-highlight',
    create: function () {
      placePairingIndicators();
      setAnswer();
    },
    sort: function (event, ui) {
      // update the location of the placeholder as the item is dragged
      let placeholder = ui.placeholder;
      let leftDiff = calculateIndent(ui, placeholder.parent());
      placeholder[0].style.marginLeft = leftDiff + 'px';
      placeholder[0].style.height = ui.item[0].style.height;
    },
    stop: function (event, ui) {
      // when the user stops interacting with the list
      let leftDiff = calculateIndent(ui, ui.item.parent());
      ui.item[0].style.marginLeft = leftDiff + 'px';
      setAnswer();
    },
  });

  if (enableIndentation) {
    $(dropzoneElementId).sortable('option', 'grid', [TABWIDTH, 1]);
  }
  $('[data-toggle="popover"]').popover();
};
