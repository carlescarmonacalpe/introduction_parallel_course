#include <string>
#include <iostream>

// 3rd Party Libraries
#include <boost/filesystem.hpp>
#include <opencv2/opencv.hpp>
#include <chrono>



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
void rgb2gray(const cv::Mat &input_image, cv::Mat &output_image){

  //Pointers
  unsigned char *input_ptr = (unsigned char*)(input_image.data);
  unsigned char *output_ptr = (unsigned char*)(output_image.data);

  for(int i = 0;i < input_image.rows;i++){
    for(int j = 0;j < input_image.cols;j++){
        unsigned char b = input_ptr[input_image.step * i + (j * 3) ] ;
        unsigned char g = input_ptr[input_image.step * i + (j * 3) + 1];
        unsigned char r = input_ptr[input_image.step * i + (j * 3) + 2];
        output_ptr[output_image.step * i + j] =  0.21 * r + 0.72 * g + 0.07 * b;
    }
  }

}

__global__ void boxFilter3x3_ver1 (unsigned char * srcD, unsigned char * dstD, int width, int height){
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y>=height)
      return;

    int widthSrc = width + 2;
    int heightSrc = height + 2;

    int sum = 0


    unsigned char i0, i1, i2, i3, i4, i5, i6, i7, i8;
    i0 = srcD[widthSrc * y + x];
    i1 = srcD[widthSrc * y + x + 1];
    i2 = srcD[widthSrc * y + x + 2];
    i3 = srcD[widthSrc * (y + 1) + x];
    i4 = srcD[widthSrc * (y + 1) + x + 1];
    i5 = srcD[widthSrc * (y + 1) + x + 2];
    i6 = srcD[widthSrc * (y + 2) + x];
    i7 = srcD[widthSrc * (y + 2) + x + 1];
    i8 = srcD[widthSrc * (y + 2) + x + 2];

    dstD[y * width + x] = (i0 + i1 + i2 + i3 + i4 + i5 + i6 + i7 + i8 ) / 9;

}

__global__ void rgb2gray_ver2(unsigned char * d_src, unsigned char * d_dst, int width, int height)
{
    int pos_x = blockIdx.x * blockDim.x + threadIdx.x;

    if (pos_x >= (width * height))
        return;

    unsigned char b = d_src[(pos_x * 3)];
    unsigned char g = d_src[(pos_x * 3) + 1];
    unsigned char r = d_src[(pos_x * 3) + 2];

    unsigned int _gray = (unsigned int)((float)(0.21 * r + 0.72 * g + 0.07 * b));
    unsigned char gray = _gray > 255 ? 255 : _gray;

    d_dst[pos_x] = gray;
}

__global__ void rgb2gray_ver1(unsigned char * d_src, unsigned char * d_dst, int width, int height)
{
    int pos_x = blockIdx.x * blockDim.x + threadIdx.x;
    int pos_y = blockIdx.y * blockDim.y + threadIdx.y;

    if (pos_x >= width || pos_y >= height )
        return;

    unsigned char b = d_src[pos_y * (width * 3) + (pos_x * 3)];
    unsigned char g = d_src[pos_y * (width * 3) + (pos_x * 3) + 1];
    unsigned char r = d_src[pos_y * (width * 3) + (pos_x * 3) + 2];

    unsigned int _gray = (unsigned int)((float)(0.21 * r + 0.72 * g + 0.07 * b));
    unsigned char gray = _gray > 255 ? 255 : _gray;

    d_dst[pos_y * width + pos_x] = gray;
}

/*! Process the specified image. First convert the image from rgb to grayscale, and 
    after this apply and average filter of size 3x3.  
    \param input_image Image to process.
    \return The processed image
*/  
cv::Mat processImage(const cv::Mat &input_image){

  cv::Mat input_image_gray(cv::Size(input_image.cols, input_image.rows), CV_8UC1);
  cv::Mat averaged_image;
  
  unsigned char *d_src;
  unsigned char *d_dst;
  
  auto start = std::chrono::steady_clock::now();

  // Memory allocation
  cudaMalloc((void**)&d_src, input_image.cols * input_image.rows * 3 *sizeof(unsigned char));
  cudaMalloc((void**)&d_dst, input_image.cols * input_image.rows * sizeof(unsigned char));

  // Copy src image to device
  cudaMemcpy(d_src, input_image.data, input_image.cols * input_image.rows * 3 *sizeof(unsigned char), cudaMemcpyHostToDevice);
  
  auto end = std::chrono::steady_clock::now();
  std::cout<< "Transfer time "<< std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count() << "ms"<<std::endl;

  //Launch the kernel
  start = std::chrono::steady_clock::now();
  
  //Scheme definition
  dim3 blkDim (32, 32, 1);
  dim3 grdDim ((input_image.cols + 31)/32, (input_image.rows + 31)/32, 1);

  rgb2gray_ver1<<<grdDim, blkDim>>>(d_src, d_dst, input_image.cols, input_image.rows);

  //Ver2
  /*
  int blockSize;      // The launch configurator returned block size 
  int minGridSize;    // The minimum grid size needed to achieve the maximum occupancy for a full device launch 
  int gridSize;       // The actual grid size needed, based on input siz
  cudaOccupancyMaxPotentialBlockSize(&minGridSize, &blockSize, rgb2gray_ver2, 0, (input_image.cols * input_image.rows)); 
  // Round up according to array size 
  gridSize = ((input_image.cols * input_image.rows) + blockSize - 1) / blockSize; 
  rgb2gray_ver2<<<gridSize, blockSize>>>(d_src, d_dst, input_image.cols, input_image.rows);
  */

  //Wait until kernel finishes
  cudaDeviceSynchronize();

  end = std::chrono::steady_clock::now();
  std::cout<< "Processing time "<< std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count() << "ms"<<std::endl;

  //copy back the result to CPU
  start = std::chrono::steady_clock::now();
  cudaMemcpy(input_image_gray.data, d_dst, input_image.cols * input_image.rows * sizeof(unsigned char), cudaMemcpyDeviceToHost);
  end = std::chrono::steady_clock::now();
  std::cout<< "Transfer time "<< std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count() << "ms"<<std::endl;
  
  // Free memory
  cudaFree(d_src);
  cudaFree(d_dst);

  // Convert RGB to Grayscale
  //rgb2gray(input_image, input_image_gray);
  
  // Average Filter
  averaged_image = averageFilter(input_image_gray);
  return averaged_image;

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
  auto i = std::begin(imagesToProcess);
  int num_image=0;
  while (i != std::end(imagesToProcess)) {
      cv::imwrite(std::to_string(num_image) + "output.tiff", processImage(*i));
      i = imagesToProcess.erase(i);
      num_image++;
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
