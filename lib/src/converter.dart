import 'package:html/dom.dart' as dom;

import 'rules.dart' show Rule;
import 'utils.dart' as util;

import 'node.dart';

const List<String> headingStyles = const ['setext', 'atx'];
const List<String> hr = const ['* * *', '- - -', '_ _ _'];
const List<String> bulletListMarker = const ['*', '-', '_'];
const List<String> codeBlockStyle = const ['indented', 'fenced'];
const List<String> fence = const ['```', '~~~'];
const List<String> emDelimiter = const ['_', '*'];
const List<String> strongDelimiter = const ['**', '__'];
const List<String> linkStyle = const ['inlined', 'referenced'];
const List<String> linkReferenceStyle = const ['full', 'collapsed', 'shortcut'];
const String br = '  ';

final options = <String, String>{
  'headingStyle': headingStyles[0],
  'hr': hr[0],
  'bulletListMarker': bulletListMarker[0],
  'codeBlockStyle': codeBlockStyle[0],
  'fence': fence[0],
  'emDelimiter': emDelimiter[0],
  'strongDelimiter': strongDelimiter[0],
  'linkStyle': linkStyle[0],
  'linkReferenceStyle': linkReferenceStyle[0],
  'br': br,
};

final _leadingNewLinesRegExp = new RegExp(r'^\n*');
final _trailingNewLinesRegExp = new RegExp(r'\n*$');

String convert(String html) {
  if (html == null || html.isEmpty) {
    return '';
  }
  var output = _process(new Node.root(html), options);
  return _postProcess(output);
}

String _postProcess(String input) {
  // this.rules.forEach(function (rule) {
  //   if (typeof rule.append === 'function') {
  //     output = join(output, rule.append(self.options))
  //   }
  // })

  // return output.replace(/^[\t\r\n]+/, '').replace(/[\t\r\n\s]+$/, '')\
  return input;
}

String _process(Node inNode, Map<String, String> options) {
  var result = '';
  for (var node in inNode.childNodes()) {
    var replacement = '';
    if (node.nodeType == 3) {
      replacement = node.isCode ? node.textContent : _escape(node.textContent);
    } else if (node.nodeType == 1) {
      replacement = _replacementForNode(node, options);
    }
    result = _join(result, replacement ?? '');
  }
  return result;
}

String _replacementForNode(Node node, Map<String, String> options) {
  var rule = Rule.findRule(node);
  var content = _process(node, options);
  var whitespace = _getFlankingWhitespace(node);
  if (whitespace['leading'] != null || whitespace['trailing'] != null)
    content = content.trim();
  return '${whitespace['leading']}${rule.replacement(content, node, options)}${whitespace['trailing']}';
}

Map<String, String> _getFlankingWhitespace(Node node) {
  var result = {};
  if (!node.isBlock) {
    var hasLeading = new RegExp(r'^[ \r\n\t]').hasMatch(node.textContent);
    var hasTrailing = new RegExp(r'[ \r\n\t]$').hasMatch(node.textContent);

    if (hasLeading && !_isFlankedByWhitespace(node.el, 'left')) {
      result['leading'] = ' ';
    }
    if (hasTrailing && !_isFlankedByWhitespace(node.el, 'right')) {
      result['trailing'] = ' ';
    }
  }
  return result;
}

bool _isFlankedByWhitespace(dom.Element el, String side) {
  dom.Element sibling;
  RegExp regExp;
  bool isFlanked;

  if (side == 'left') {
    sibling = el.previousElementSibling;
    regExp = new RegExp(r' $');
  } else {
    sibling = el.nextElementSibling;
    regExp = new RegExp(r'^ ');
  }

  if (sibling != null) {
    if (sibling.nodeType == 3) {
      isFlanked = regExp.hasMatch(sibling.innerHtml);
    } else if (sibling.nodeType == 1 && !util.isBlock(sibling)) {
      isFlanked = regExp.hasMatch(sibling.text);
    }
  }
  return isFlanked;
}

// Determines the new lines between the current output and the replacement
String _separatingNewlines(String output, String replacement) {
  var newlines = [
    _trailingNewLinesRegExp.stringMatch(output),
    _leadingNewLinesRegExp.stringMatch(replacement),
  ];
  newlines.sort((a, b) => a.compareTo(b));

  var maxNewlines = newlines.last;
  return maxNewlines.length < 2 ? maxNewlines : '\n\n';
}

_join(String string1, String string2) {
  var separator = _separatingNewlines(string1, string2);
  // // Remove trailing/leading newlines and replace with separator
  string1 = string1.replaceAll(_trailingNewLinesRegExp, '');
  string2 = string2.replaceAll(_leadingNewLinesRegExp, '');
  return '$string1$separator$string2';
}

_escape(String input) {
  if (input == null) return null;
  return input
      .replaceAllMapped(new RegExp(r'\\(\S)'),
          (match) => '\\\\${match[1]}') // Escape backslash escapes!
      .replaceAllMapped(new RegExp(r'^(#{1,6} )', multiLine: true),
          (match) => '\\${match[1]}') // Escape headings
      .replaceAllMapped(new RegExp(r'^([-*_] *){3,}$', multiLine: true),
          (match) {
        return match[0].split(match[1]).join('\\${match[1]}');
      })
      .replaceAllMapped(new RegExp(r'^(\W* {0,3})(\d+)\. ', multiLine: true),
          (match) => '${match[1]}${match[2]}\\. ')
      .replaceAllMapped(new RegExp(r'^([^\\\w]*)[*+-] ', multiLine: true),
          (match) {
        return match[0].replaceAllMapped(
            new RegExp(r'([*+-])'), (match) => '\\${match[1]}');
      })
      .replaceAllMapped(
          new RegExp(r'^(\W* {0,3})> '), (match) => '${match[1]}\\> ')
      .replaceAllMapped(new RegExp(r'\*+(?![*\s\W]).+?\*+'),
          (match) => match[0].replaceAll(new RegExp(r'\*'), '\\*'))
      .replaceAllMapped(new RegExp(r'_+(?![_\s\W]).+?_+'),
          (match) => match[0].replaceAll(new RegExp(r'_'), '\\_'))
      .replaceAllMapped(new RegExp(r'`+(?![`\s\W]).+?`+'),
          (match) => match[0].replaceAll(new RegExp(r'`'), '\\`'))
      .replaceAllMapped(new RegExp(r'[\[\]]'), (match) => '\\${match[0]}');
}
