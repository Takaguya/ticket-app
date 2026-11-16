/// What a business sells, chosen when it registers.
enum BusinessType {
  events('Events'),
  bus('Bus'),
  cinema('Cinema'),
  admission('Admission');

  const BusinessType(this.label);

  final String label;
}
