import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user/features/catalog/domain/entities/available_categories.dart';
import 'package:user/features/catalog/domain/entities/ticket_category.dart';
import 'package:user/features/catalog/presentation/organisms/category_shortcuts.dart';

void main() {
  Future<(List<TicketCategory>, List<TicketCategory>)> pump(
    WidgetTester tester,
    AvailableCategories available,
  ) async {
    final opened = <TicketCategory>[];
    final soon = <TicketCategory>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryShortcuts(available: available, onSelected: opened.add, onComingSoon: soon.add),
        ),
      ),
    );
    return (opened, soon);
  }

  testWidgets('with the Pin API only Events opens; Bus, Cinema and Admission say "Soon"', (tester) async {
    final (opened, soon) = await pump(tester, AvailableCategories.eventsOnly);

    expect(find.text('Soon'), findsNWidgets(3));
    for (final title in ['Events', 'Bus', 'Cinema', 'Admission']) {
      await tester.tap(find.text(title));
    }

    expect(opened, [TicketCategory.events]);
    expect(soon, [TicketCategory.bus, TicketCategory.cinema, TicketCategory.admission]);
  });

  testWidgets('with the Pin API today Events and Bus open; Cinema and Admission say "Soon"', (tester) async {
    final (opened, soon) = await pump(tester, AvailableCategories.eventsAndBuses);

    expect(find.text('Soon'), findsNWidgets(2));
    for (final title in ['Events', 'Bus', 'Cinema', 'Admission']) {
      await tester.tap(find.text(title));
    }

    expect(opened, [TicketCategory.events, TicketCategory.bus]);
    expect(soon, [TicketCategory.cinema, TicketCategory.admission]);
  });

  testWidgets('with the mock all four open and none says "Soon"', (tester) async {
    final (opened, soon) = await pump(tester, AvailableCategories.all);

    expect(find.text('Soon'), findsNothing);
    for (final title in ['Events', 'Bus', 'Cinema', 'Admission']) {
      await tester.tap(find.text(title));
    }

    expect(opened, TicketCategory.values);
    expect(soon, isEmpty);
  });
}
