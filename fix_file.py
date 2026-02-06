import sys

file_path = r'c:\Users\Leandro\dri\lib\grade_aulas_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    # Detect the end of the cells map
    if i + 1 == 1948:
        new_lines.append('                                  }).toList(),\n')
        new_lines.append('                                ],\n')
        new_lines.append('                              ),\n')
        new_lines.append('                            ),\n')
        new_lines.append('                          ),\n')
        new_lines.append('                        ),\n')
        new_lines.append('                      ],\n')
        new_lines.append('                    ),\n')
        new_lines.append('                  ),\n')
        new_lines.append('              ),\n')
        new_lines.append('      floatingActionButton: _usuarioPodeEditar()\n')
        skip = True
    elif skip:
        if 'floatingActionButton: _usuarioPodeEditar()' in line:
            # Already added floatingActionButton line, just stop skipping from here
            skip = False
    else:
        new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
