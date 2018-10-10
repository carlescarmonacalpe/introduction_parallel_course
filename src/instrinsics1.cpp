#include <string>
#include <iostream>
#include <omp.h>
// 3rd Party Libraries
#include <boost/filesystem.hpp>
#include <opencv2/opencv.hpp>

using namespace boost::filesystem;

/*! Convert the specified image to grayscale.  
    \param input_image Image to process.
    \return Output image.
*/  
cv::Mat averageFilter(const cv::Mat &input_image){

  int cols = input_image.cols;
  int rows = input_image.rows;

  // Simplify borders problem
  cv::Mat input_image_extra_border(cv::Size(cols, rows), CV_8UC1);
  cv::Mat output_image(cv::Size(cols, rows), CV_8UC1);
  cv::copyMakeBorder(input_image, input_image_extra_border, 1, 1, 1, 1, cv::BORDER_REPLICATE);

  std::cout << "\tInput image size: " << input_image.rows << ", " << input_image.cols << std::endl;
  std::cout << "\tInput with border image size: " << input_image_extra_border.rows << ", " 
            << input_image_extra_border.cols << std::endl;


  const int offset[9] = { -(int) input_image.step + 1, -(int) input_image.step, -(int) input_image.step - 1, \
                          -1, 0, +1, \
                          (int) input_image.step - 1, (int) input_image.step, (int) input_image.step + 1};

  //Pointers
  unsigned char *input_ptr = (unsigned char*)(input_image_extra_border.data);
  unsigned char *output_ptr = (unsigned char*)(output_image.data);

  for(int i = 1;i < input_image.rows;i++){
    for(int j = 1;j < input_image.cols;j++){

      int average = 0 ;
      for (int k = 0; k < 9; ++k)
          average += input_ptr[input_image_extra_border.step * i + j + offset[k]];
      average = average / 9;
      output_ptr[output_image.step * (i - 1) + (j - 1)] = (unsigned char) average;
    }
  }

  return output_image;

}

/*! Convert the specified image to grayscale.  
    \param input_image Image to process.
    \param input_image Output image.
*/  
cv::Mat* rgb2gray(const cv::Mat &input_image, cv::Mat &output_image){

  //Pointers
  //const unsigned char *input_ptr = (const unsigned char*)(input_image.data);
  const uchar* input_ptr = (const uchar*)(input_image.data);
  const uchar* output_ptr = (const uchar*)(output_image.data);
  //unsigned char *output_ptr = (unsigned char*)(output_image.data);
  unsigned char b;
  unsigned char g;
  unsigned char r;
  int tid;


  std::cout << "Input image:" << input_image.cols << std::endl;
  __m128i ssse3_red_indeces_0 = _mm_set_epi8(-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 15, 12, 9, 6, 3, 0);
  __m128i ssse3_red_indeces_1 = _mm_set_epi8(-1, -1, -1, -1, -1, 14, 11, 8, 5, 2, -1, -1, -1, -1, -1, -1);
  __m128i ssse3_red_indeces_2 = _mm_set_epi8(13, 10, 7, 4, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1);
  __m128i ssse3_green_indeces_0 = _mm_set_epi8(-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 13, 10, 7, 4, 1);
  __m128i ssse3_green_indeces_1 = _mm_set_epi8(-1, -1, -1, -1, -1, 15, 12, 9, 6, 3, 0, -1, -1, -1, -1, -1);
  __m128i ssse3_green_indeces_2 = _mm_set_epi8(14, 11, 8, 5, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1);
  __m128i ssse3_blue_indeces_0 = _mm_set_epi8(-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 14, 11, 8, 5, 2);
  __m128i ssse3_blue_indeces_1 = _mm_set_epi8(-1, -1, -1, -1, -1, -1, 13, 10, 7, 4, 1, -1, -1, -1, -1, -1);
  __m128i ssse3_blue_indeces_2 = _mm_set_epi8(15, 12, 9, 6, 3, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1);

  for(int i = 0;i < output_image.rows;i++){
    for(int j = 0;j < (output_image.cols*3) - 48
      ;j+=48){
        const __m128i chunk0 = _mm_loadu_si128((const __m128i*)(input_ptr));
        const __m128i chunk1 = _mm_loadu_si128((const __m128i*)(input_ptr + 16));
        const __m128i chunk2 = _mm_loadu_si128((const __m128i*)(input_ptr + 32));
        const __m128i green = _mm_or_si128(_mm_or_si128(_mm_shuffle_epi8(chunk0, ssse3_green_indeces_0),
        _mm_shuffle_epi8(chunk1, ssse3_green_indeces_1)), _mm_shuffle_epi8(chunk2, ssse3_green_indeces_2));
        _mm_store_si128((__m128i*)(output_ptr), green);

        input_ptr += 48;
        output_ptr += 16;
    }
    
  }

  std::cout << "OUT" << std::endl;

}

/*! Process the specified image. First convert the image from rgb to grayscale, and 
    after this apply and average filter of size 3x3.  
    \param input_image Image to process.
    \return The processed image
*/  
cv::Mat processImage(const cv::Mat &input_image){

  cv::Mat input_image_gray(cv::Size(input_image.cols, input_image.rows), CV_8UC1);
  cv::Mat averaged_image;

  // Convert RGB to Grayscale
  rgb2gray(input_image, input_image_gray);
  
  // Average Filter
  averaged_image = averageFilter(input_image_gray);
  return input_image_gray;

}

/*! Process all the images defined on the std::vector.  
    \param filenames Vector of directory_entry with that containsl all the image to process
*/  
void processImages(std::vector<directory_entry> filenames){

  std::vector<cv::Mat> imagesToProcess;
  std::vector<directory_entry>::iterator it;

  // Load images
  for(it = filenames.begin(); it != filenames.end(); it++ ) {
    std::cout << "Processing image " << it->path() << ":" << std::endl;
    cv::Mat img = cv::imread(it->path().c_str());
    imagesToProcess.push_back(img);
    //
  }

  // Process images
  for(int i=0; i< imagesToProcess.size(); i++){
    cv::imwrite(std::to_string(i) + "output.tiff", processImage(imagesToProcess[i]));
    imagesToProcess.erase(imagesToProcess.begin() + i);
  }
}


int main(int argc, char* argv[])
{
  if (argc < 2)
  {
    std::cout << "Usage: serial_base <path_img_folder>\n";
    return 1;
  }

  std::vector<directory_entry> filenames; // To save the file names in a vector.
  path input_path (argv[1]); // To define the path

  try
  {
    if (exists(input_path))
    {
      if (is_directory(input_path))
      {
        // Add the filenames to the vector
        copy(directory_iterator(input_path), directory_iterator(),
             back_inserter(filenames));

        // Process the all the images
        processImages(filenames);
      }
      else{
        std::cout << input_path << " exists, but is not a directory\n";
      }
    }
    else
      std::cout << input_path << " does not exist\n";
  }

  catch (const filesystem_error& ex)
  {
    std::cout << ex.what() << '\n';
  }

  return 0;
}
