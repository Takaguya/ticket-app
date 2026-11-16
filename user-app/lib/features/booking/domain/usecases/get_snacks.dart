import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/snack.dart';
import '../repositories/booking_repository.dart';

/// What a cinema sells at its counter. Takes the theatre's ID.
class GetSnacks implements UseCase<List<Snack>, String> {
  const GetSnacks(this._repository);

  final BookingRepository _repository;

  @override
  Future<Result<List<Snack>>> call(String theatreId) => _repository.snacks(theatreId: theatreId);
}
