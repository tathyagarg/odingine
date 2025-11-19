package matrix_math

import "core:math"

translate :: proc(m: matrix[4, 4]f32, v: [3]f32) -> matrix[4, 4]f32 {
	/*
   * GLM equivalent:
   *
   * mat<4, 4, T, Q> Result(m);
	 * Result[3] = m[0] * v[0] + m[1] * v[1] + m[2] * v[2] + m[3];
	 * return Result;
   *
   */

	translation_matrix: ^matrix[4, 4]f32 = new_clone(m)
	translation_matrix[3][0] += v[0]
	translation_matrix[3][1] += v[1]
	translation_matrix[3][2] += v[2]

	return translation_matrix^
}

rotate :: proc(m: matrix[4, 4]f32, angle: f32, axis: [3]f32) -> matrix[4, 4]f32 {
	/*
   * GLM equivalent:
   *
 	 *  T const a = angle;
	 *  T const c = cos(a);
	 *  T const s = sin(a);
   *
	 *  vec<3, T, Q> axis(normalize(v));
	 *  vec<3, T, Q> temp((T(1) - c) * axis);
   *
	 *  mat<4, 4, T, Q> Rotate;
	 *  Rotate[0][0] = c + temp[0] * axis[0];
	 *  Rotate[0][1] = temp[0] * axis[1] + s * axis[2];
	 *  Rotate[0][2] = temp[0] * axis[2] - s * axis[1];
   *
	 *  Rotate[1][0] = temp[1] * axis[0] - s * axis[2];
	 *  Rotate[1][1] = c + temp[1] * axis[1];
	 *  Rotate[1][2] = temp[1] * axis[2] + s * axis[0];
   *
	 *  Rotate[2][0] = temp[2] * axis[0] + s * axis[1];
	 *  Rotate[2][1] = temp[2] * axis[1] - s * axis[0];
	 *  Rotate[2][2] = c + temp[2] * axis[2];
   *
	 *  mat<4, 4, T, Q> Result;
	 *  Result[0] = m[0] * Rotate[0][0] + m[1] * Rotate[0][1] + m[2] * Rotate[0][2];
	 *  Result[1] = m[0] * Rotate[1][0] + m[1] * Rotate[1][1] + m[2] * Rotate[1][2];
	 *  Result[2] = m[0] * Rotate[2][0] + m[1] * Rotate[2][1] + m[2] * Rotate[2][2];
	 *  Result[3] = m[3];
	 *  return Result;
   *
   */

	c := math.cos(angle)
	s := math.sin(angle)

	axis_length := math.sqrt(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2])
	n_axis := [3]f32{axis[0] / axis_length, axis[1] / axis_length, axis[2] / axis_length}
	temp := [3]f32{(1.0 - c) * n_axis[0], (1.0 - c) * n_axis[1], (1.0 - c) * n_axis[2]}

	rotation_matrix: matrix[4, 4]f32
	rotation_matrix[0][0] = c + temp[0] * n_axis[0]
	rotation_matrix[0][1] = temp[0] * n_axis[1] + s * n_axis[2]
	rotation_matrix[0][2] = temp[0] * n_axis[2] - s * n_axis[1]
	rotation_matrix[0][3] = 0.0

	rotation_matrix[1][0] = temp[1] * n_axis[0] - s * n_axis[2]
	rotation_matrix[1][1] = c + temp[1] * n_axis[1]
	rotation_matrix[1][2] = temp[1] * n_axis[2] + s * n_axis[0]
	rotation_matrix[1][3] = 0.0

	rotation_matrix[2][0] = temp[2] * n_axis[0] + s * n_axis[1]
	rotation_matrix[2][1] = temp[2] * n_axis[1] - s * n_axis[0]
	rotation_matrix[2][2] = c + temp[2] * n_axis[2]
	rotation_matrix[2][3] = 0.0

	rotation_matrix[3][0] = 0.0
	rotation_matrix[3][1] = 0.0
	rotation_matrix[3][2] = 0.0
	rotation_matrix[3][3] = 1.0

	result: ^matrix[4, 4]f32 = new_clone(m)
	for i: int = 0; i < 3; i += 1 {
		result[0][i] =
			m[0][0] * rotation_matrix[0][i] +
			m[1][0] * rotation_matrix[1][i] +
			m[2][0] * rotation_matrix[2][i]
		result[1][i] =
			m[0][1] * rotation_matrix[0][i] +
			m[1][1] * rotation_matrix[1][i] +
			m[2][1] * rotation_matrix[2][i]
		result[2][i] =
			m[0][2] * rotation_matrix[0][i] +
			m[1][2] * rotation_matrix[1][i] +
			m[2][2] * rotation_matrix[2][i]
	}

	return result^
}

scale :: proc(m: matrix[4, 4]f32, v: [3]f32) -> matrix[4, 4]f32 {
	/*
   * GLM equivalent:
   *
   * mat<4, 4, T, Q> Result(m);
   * Result[0] *= v[0];
   * Result[1] *= v[1];
   * Result[2] *= v[2];
   * return Result;
   *
   */

	scaled_matrix: ^matrix[4, 4]f32 = new_clone(m)
	for i: int = 0; i < 4; i += 1 {
		scaled_matrix[0][i] *= v[0]
		scaled_matrix[1][i] *= v[1]
		scaled_matrix[2][i] *= v[2]
	}

	return scaled_matrix^
}
