import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Utility class for category-related functions and constants
class CategoryUtils {
  // Map of category names to their corresponding icons
  static Map<String, IconData> getCategoryIcons() {
    return {
      'Reading': FontAwesomeIcons.bookOpen,
      'Writing & Language': FontAwesomeIcons.pencil,
      'Math - Calculator': FontAwesomeIcons.calculator,
      'Math - No Calculator': FontAwesomeIcons.solidCircleXmark,
      'Vocabulary': FontAwesomeIcons.book,
      'Grammar': FontAwesomeIcons.paragraph,
      'Algebra': FontAwesomeIcons.superscript,
      'Geometry': FontAwesomeIcons.drawPolygon,
      'Data Analysis': FontAwesomeIcons.chartPie,
      'Test Strategies': FontAwesomeIcons.lightbulb,
      'Practice Tests': FontAwesomeIcons.clipboardCheck,
    };
  }

  // Get icon for a specific category
  static IconData getCategoryIcon(String? category) {
    if (category == null) return FontAwesomeIcons.layerGroup;
    return getCategoryIcons()[category] ?? FontAwesomeIcons.layerGroup;
  }

  // Get Font Awesome icon as widget
  static FaIcon getFontAwesomeIcon(
    String? category, {
    double size = 16,
    Color? color,
    bool isSelected = false,
  }) {
    final IconData icon = getCategoryIcon(category);
    return FaIcon(
      icon,
      size: size,
      color: color ?? (isSelected ? Colors.white : getCategoryColor(category)),
    );
  }

  // Map of category names to their corresponding colors
  static Map<String, Color> getCategoryColors() {
    return {
      'Reading': Colors.blue.shade500,
      'Writing & Language': Colors.indigo.shade400,
      'Math - Calculator': Colors.green.shade500,
      'Math - No Calculator': Colors.green.shade700,
      'Vocabulary': Colors.purple.shade400,
      'Grammar': Colors.purple.shade600,
      'Algebra': Colors.orange.shade400,
      'Geometry': Colors.orange.shade600,
      'Data Analysis': Colors.red.shade400,
      'Test Strategies': Colors.teal.shade500,
      'Practice Tests': Colors.amber.shade600,
    };
  }

  // Get color for a specific category
  static Color getCategoryColor(String? category) {
    if (category == null) return Colors.blue.shade400;
    return getCategoryColors()[category] ?? Colors.blue.shade400;
  }

  // Create a category chip with icon and name
  static Widget buildCategoryChip({
    required String category,
    required VoidCallback onTap,
    bool isSelected = false,
    double scale = 1.0,
  }) {
    final color = getCategoryColor(category);
    final icon = getCategoryIcon(category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: 6 * scale,
          vertical: 4 * scale,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 8 * scale,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20 * scale),
          border: Border.all(
            color: isSelected ? Colors.transparent : color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              icon is IconData ? icon as IconData : FontAwesomeIcons.layerGroup,
              size: 16 * scale,
              color: isSelected ? Colors.white : color,
            ),
            SizedBox(width: 8 * scale),
            Text(
              category,
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a horizontal scrollable list of category chips
  static Widget buildCategoryChipsList({
    required List<String> categories,
    required String? selectedCategory,
    required Function(String?) onCategorySelected,
  }) {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "All" option
          GestureDetector(
            onTap: () => onCategorySelected(null),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selectedCategory == null
                    ? Colors.blue.shade400
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                boxShadow: selectedCategory == null
                    ? [
                        BoxShadow(
                          color: Colors.blue.shade200.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.layerGroup,
                    size: 16,
                    color: selectedCategory == null
                        ? Colors.white
                        : Colors.blue.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'All',
                    style: TextStyle(
                      color: selectedCategory == null
                          ? Colors.white
                          : Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Other categories
          ...categories.map((category) {
            final isSelected = category == selectedCategory;
            final color = getCategoryColor(category);
            final icon = getCategoryIcon(category);

            return GestureDetector(
              onTap: () => onCategorySelected(category),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    FaIcon(
                      icon is IconData
                          ? icon as IconData
                          : FontAwesomeIcons.layerGroup,
                      size: 16,
                      color: isSelected ? Colors.white : color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
