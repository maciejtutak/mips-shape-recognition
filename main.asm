#################################################################################
#										#
#  Ecoar L3, Author: Maciej Tutak 					#
#  Task: Determine the shape on the input. 3.7 SET 3				#
#  http://galera.ii.pw.edu.pl/~zsz/ecoar/ecoar_MIPS_projects_2016-2.pdf #
#  based on: https://en.wikipedia.org/wiki/BMP_file_format			#
#  											#
#  Number of comments is excessive, but they are only there because  	#
#  it is a university project.  						#
#										#
#################################################################################

# s06-1.bmp header hexdump
# 0000000 42 4d 36 84 03 00 00 00 00 00 36 00 00 00 28 00
# 0000010 00 00 40 01 00 00 f0 00 00 00 01 00 18 00 00 00
# 0000020 00 00 00  84 03 00 13 0b 00 00 13 0b 00 00 00 00
# 0000030 00 00 00 00 00 00 ff ff ff ff ff ff ff ff ff ff
# 0000040 ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff

.data
inputMsg:	.asciiz "Enter the file name: "
output1:	.asciiz "Shape 1\n"
output2:	.asciiz "Shape 2\n"
input:		.asciiz "./s06-1.bmp"
inputName:	.space	128

errorMsg:	.asciiz	"Descriptor error. Program restarting.\n"
bitmapMsg: 	.asciiz "The file entered is not a bitmap. Please enter a 24-bit bitmap as input. Program restarting.\n"
formatMsg:	.asciiz	"The file entered is a bitmap, but is not 24-bit. Program restarting.\n"
sizeMsg:	.asciiz	"The file is wrong size. Program restarting.\n"

buffer:		.space 	2 				# for proper header alignment in data section

header: 	.space 	54				# the bmp file header size

width:		.word	320				# width of the bmp, is at header+18
height:		.word	240				# height of the bmp, is at header+22

.text
main:
	# begin the program, print prompt
	li	$v0, 4					# syscall-4 print string
	la	$a0, inputMsg				# load address of the input msg
	syscall

	# read the input file name
	li 	$v0, 8					# syscall-8 read string
	la	$a0, inputName				# load address of the inputName
	li 	$a1, 128				# load the maximum number of characters to read
	syscall

	# cut the '\n' from the inputName
	move	$t0, $zero				# load 0 to $t0 to make sure that it starts from the beginning of the string
	li	$t2, '\n'				# load the '\n' character to the $t2 register

	# find the '\n'
findNewLine:
	lb	$t1, inputName($t0)			# read the inputName byte by byte, starting from $t0
	beq	$t1, $t2, removeNewLine			# if it finds the '\n', go to removeNewLine to remove it
	addi 	$t0, $t0, 1				# otherwise, increment the iterator and read next byte
	j 	findNewLine

	# remove the '\n', swap with '\0'
removeNewLine:
	li	$t1, '\0'				# replace '\n' with '\0'
	sb	$t1, inputName($t0)

	# after processing the inputName we can finally open the input file for reading, the idea here is to read the
	# file descriptor, check for it's correctness, save for closing the file, read the bmp file header info,
	# check the dimensions of the image (if it is 320x240)
	# check if the file is indeed a bitmap and if it is 24 bit format (uncompressed)

	# open input file for reading
	li	$v0, 13					# syscall-13 open file
	la	$a0, inputName				# load filename address
	li 	$a1, 0					# 0 flag for reading the file
	li	$a2, 0					# mode 0
	syscall
							# $v0 contains the file descriptor
	bltz	$v0, fileError				# if $v0=-1, there is a descriptor error, go to fileError
							# and the file cannot be read
	move	$s0, $v0				# save the file descriptor from $v0 for closing the file

	# read the header data
	li	$v0, 14					# syscall-14 read from file
	move	$a0, $s0				# load the file descriptor
	la	$a1, header				# load header address to store
	li	$a2, 54					# read first 54 bytes of the file
	syscall

	# check if it is a bitmap
	li	$t0, 0x4D42 				# 0X4D42 is the signature for a bitmap (hex for "BM")
	lhu	$t1, header				# the signature is stored in the first two bytes (header+0)
							# lhu - load halfword unsigned - loads the first 2 bytes into $t1 register
	bne	$t0, $t1, bitmapError  			# if these two aren't equal then the input is not a bitmap

	# check if it is the right size
	lw	$t0, width				# load the width (320) to $t0
	lw 	$s1, header+18				# read the file width from the header information (offset of 18) - need to read only 2 bytes
	bne	$t0, $s1, sizeError			# if not equal, go to sizeError
	lw	$t0, height				# load the height (240) to $t0
	lw	$s2, header+22				# read the file height from the header information (offset of 22) - need to read only 2 bytes
	bne	$t0, $s2, sizeError			# if not equal, go to sizeError

	# confirm that the bitmap is actually 24 bits
	li	$t0, 24					# store 24 into $t0, because it is a 24-bit bitmap (uncompressed)
	lb	$t1, header+28				# offset of 28 points at the header's indication of how many bits the bmp is
							# (size of 2 bytes, we only need the first one)
	bne	$t0, $t1, formatError			# if the two aren't equal, it means the entered file is not a 24 bit bmp, go to formatError

	# everything is checked, we can proceed
	lw	$s3, header+34				# store the size of the data section of the image

	# read image data into array
	li	$v0, 9					# syscall-9, allocate heap memory
	move	$a0, $s3				# load size of data section
	syscall						# sbrk - function returns the address of allocated memory in $v0
	move	$s4, $v0				# store the base address of the array in $s4 from $v0

	li	$v0, 14					# syscall-14, read from file
	move	$a0, $s0				# load the file descriptor
	move	$a1, $s4				# load base address of array
	move	$a2, $s3				# load size of data section
	syscall

	# close the file
closeFile:
	li	$v0, 16					# syscall-16 close file
	move	$a0, $s0				# load the file descriptor to $a0 to close
	syscall

	# done with the file I/O, time for shape recognition

#################################################################################
#										#
#			   MAIN PART OF THE PROGRAM				#
#										#
#################################################################################

	# the idea is to recognize the shapes by the amount of corners they have, a cross has 8 white corners
	# and a T letter has only 6. Therefore if I find more that 6 corners I will print shape2
	# a corner can only be achieved, when in a 2x2 square we have 1 white and 3 black pixels
	# because of the white border on the image, I do not need to check the bounds of the image;
	# also, the only possibility for a white corner appearance is when there is exactly 1 white pixel
	# the file origin (0,0) is in the bottom left corner
	# the colors are in the BGR format, each pixel is 24 bits wide = 3 bytes

shapeRecognition:
	move	$t9, $s4				# load base address of the image
	li	$t4, 0					# width counter
	move	$t6, $s1				# width offset
	mul	$t6, $t6, 3				# multiply to get the number of BGR threes in a row
	li	$t7, 0					# white pixel counter (FFF)
	li	$t8, 0					# corner counter (if 3 black and 1 white)


	# I need to calculate the [w-1][h-1] pixel to use it as the ending point, otherwise the program might go out of bounds
	move	$t2, $s3				# move the size of the array to $t2 (0x38400 = 230400)
	sub 	$t2, $t2, 3				# reference to [w-1]
	sub	$t2, $t2, $t6				# reference to [h-1]

recognitionLoop:
	lb 	$t0, 0($t9)				# load byte - since the file is B&W we only need the value of 1 byte, and from that we can
							# determine whether it is black or white. It is a bottom-left pixel
	beqz 	$t0, recognitionLoop2 			# if black, skip the incrementation
	jal	whitePixelUp

recognitionLoop2:
	addi	$t9, $t9, 3				# add pixel offset
	lb 	$t0, 0($t9)				# load byte - since the file is B&W we only need the value of 1 byte, and from that we can
							# determine whether it is black or white. It is a bottom-right pixel
	subi	$t9, $t9, 3				# recover from the pixel offset
	beqz	$t0, recognitionLoop3			# if black, skip the incrementation
	jal	whitePixelUp

recognitionLoop3:
	add	$t9, $t9, $t6
	lb 	$t0, 0($t9)				# load byte - since the file is B&W we only need the value of 1 byte, and from that we can
							# determine whether it is black or white. It is a top-left pixel
	beqz	$t0, recognitionLoop4			# if black, skip the incrementation
	jal	whitePixelUp

recognitionLoop4:
	add	$t9, $t9, 3				# add pixel offset
	lb 	$t0, 0($t9)				# load byte - since the file is B&W we only need the value of 1 byte, and from that we can
							# determine whether it is black or white. It is a top-right pixel
	subi	$t9, $t9, 3				# recover from the pixel offset
	sub	$t9, $t9, $t6				# recover from the pixel offset
	beqz	$t0, recognitionLoop5			# if black, skip the incrementation
	jal	whitePixelUp

	# check if it is a corner
recognitionLoop5:
	beq	$t5, 1, corner				# if there is one pixel in the 2x2, it is a corner
	j 	nextPixel

corner:
	addi	$t8, $t8, 1				# increment the corner counter

nextPixel:
	li	$t5, 0					# reset the white pixel counter
	addi	$t9, $t9, 3				# move on to the next pixel
	addi 	$t4, $t4, 3				# size counter
	# check if the end is reached
	bge 	$t4, $t2, endLoop
	j 	recognitionLoop


whitePixelUp:
	addi 	$t5, $t5, 1
	jr	$ra

endLoop:

	bgt 	$t8, 6, shape2				# if it has more than 6 corners it is the other shape

shape1:
	li	$v0, 4					# syscall-4 print string
	la	$a0, output1				# load address of the output1
	syscall
	j 	end

shape2:
	li	$v0, 4					# syscall-4 print string
	la	$a0, output2				# load address of the output2
	syscall

#################################################################################
#										#
#		    THE END OF MAIN PART OF THE PROGRAM				#
#										#
#################################################################################

	# terminate the program
end:
	li 	$v0, 10					# syscall-10 exit
	syscall


	# print file error message
fileError:
	li	$v0, 4					# syscall-4 print string
	la	$a0, errorMsg				# print the message
	syscall
	j	main					# restart the program

	# print bitmap error message
bitmapError:
	li	$v0, 4					# syscall-4 print string
	la	$a0, bitmapMsg				# print the message
	syscall
	j	main					# restart the program

	# print format error message
formatError:
	li	$v0, 4					# syscall-4 print string
	la	$a0, formatMsg				# print the message
	syscall
	j	main					# restart the program

	# print size error message
sizeError:
	li	$v0, 4					# syscall-4 print string
	la	$a0, sizeMsg				# print the message
	syscall
	j	main					# restart the program
