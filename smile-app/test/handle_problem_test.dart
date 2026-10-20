import 'package:flutter_test/flutter_test.dart';
import 'package:smile_app/services/profile_service.dart';

void main() {
  test('a Smile name problem names exactly the one thing that is wrong', () {
    expect(handleProblem('anna.berger'), isNull);
    expect(handleProblem('an'), HandleProblem.tooShort);
    expect(handleProblem('a' * 25), HandleProblem.tooLong);
    expect(handleProblem('anna!'), HandleProblem.badChar);
    expect(firstBadHandleChar('anna!'), '!');
    expect(handleProblem('anna berger'), HandleProblem.space);
    expect(handleProblem('.anna'), HandleProblem.badStart);
    expect(handleProblem('_anna'), HandleProblem.badStart);
    expect(handleProblem('anna..berger'), HandleProblem.doubleDot);
    expect(handleProblem('anna.'), HandleProblem.dotAtEnd);
    expect(handleProblem('admin'), HandleProblem.reserved);
    expect(handleProblem('anna_'), isNull); // an underscore may end it
  });
}
